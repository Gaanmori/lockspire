// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Gabriel Ángel Montoya Rico

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lockspire/design/lockspire_colors.dart';
import 'package:lockspire/features/appearance/domain/appearance_preference.dart';
import 'package:lockspire/features/appearance/domain/ports/appearance_preferences_port.dart';
import 'package:lockspire/features/appearance/presentation/appearance_controller.dart';
import 'package:lockspire/features/appearance/presentation/appearance_theme.dart';
import 'package:lockspire/features/appearance/presentation/providers/app_themes_provider.dart';
import 'package:lockspire/features/appearance/presentation/providers/appearance_preferences_port_provider.dart';
import 'package:lockspire/features/appearance/presentation/providers/system_accent_color_provider.dart';

import '../../../support/fakes/fake_system_accent.dart';

class _FakePort implements AppearancePreferencesPort {
  AppearancePreference stored;

  _FakePort([this.stored = AppearancePreference.defaults]);

  @override
  Future<AppearancePreference> load() async => stored;

  @override
  Future<void> save(AppearancePreference preference) async {
    stored = preference;
  }
}

ProviderContainer _container(_FakePort port, {int? systemArgb}) {
  final container = ProviderContainer(
    overrides: [
      appearancePreferencesPortProvider.overrideWithValue(port),
      systemAccentColorPortProvider.overrideWithValue(
        FakeSystemAccent(systemArgb),
      ),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

LockspirePalette? _palette(ThemeData theme) =>
    theme.extension<LockspirePalette>();

Future<AppThemes> _themes(ProviderContainer container) async {
  await container.read(appearanceControllerProvider.future);
  await container.read(systemAccentColorProvider.future);
  return container.read(appThemesProvider);
}

void main() {
  test('sin nada guardado: Grafito, según el sistema (ADR 0036)', () async {
    final container = _container(_FakePort());
    final themes = await _themes(container);
    expect(
      container.read(appearanceControllerProvider).value,
      AppearancePreference.defaults,
    );
    expect(themes.mode, ThemeMode.system);
    expect(_palette(themes.light), LockspirePalettes.grafito);
    expect(_palette(themes.dark), LockspirePalettes.grafitoOscuro);
  });

  test('carga lo guardado', () async {
    final container = _container(
      _FakePort(
        const AppearancePreference(
          family: ThemeFamilyId.windows,
          mode: AppearanceMode.dark,
        ),
      ),
    );
    final themes = await _themes(container);
    expect(themes.mode, ThemeMode.dark);
    expect(_palette(themes.dark), LockspirePalettes.windowsOscuro);
  });

  test('cambiar familia y modo se aplica y se guarda', () async {
    final port = _FakePort();
    final container = _container(port);
    await _themes(container);
    final controller = container.read(appearanceControllerProvider.notifier);

    await controller.setFamily(ThemeFamilyId.mint);
    await controller.setMode(AppearanceMode.light);

    const expected = AppearancePreference(
      family: ThemeFamilyId.mint,
      mode: AppearanceMode.light,
    );
    expect(container.read(appearanceControllerProvider).value, expected);
    expect(port.stored, expected);
    expect(
      _palette(container.read(appThemesProvider).light),
      LockspirePalettes.mint,
    );
  });

  group('Colores del sistema', () {
    const blue = 0xFF1565C0;

    test('genera la paleta desde el color del sistema', () async {
      final container = _container(
        _FakePort(
          const AppearancePreference(
            family: ThemeFamilyId.sistema,
            mode: AppearanceMode.light,
          ),
        ),
        systemArgb: blue,
      );
      final themes = await _themes(container);
      expect(
        _palette(themes.light),
        LockspirePalette.fromSeed(const Color(blue), Brightness.light),
      );
      expect(_palette(themes.dark)!.isDark, isTrue);
    });

    test('sin color del sistema, usa Grafito', () async {
      final container = _container(
        _FakePort(
          const AppearancePreference(
            family: ThemeFamilyId.sistema,
            mode: AppearanceMode.system,
          ),
        ),
      );
      final themes = await _themes(container);
      expect(_palette(themes.light), LockspirePalettes.grafito);
    });

    test('dos paletas del mismo color son iguales (la caché de temas '
        'las reutiliza)', () {
      expect(
        LockspirePalette.fromSeed(const Color(blue), Brightness.dark),
        LockspirePalette.fromSeed(const Color(blue), Brightness.dark),
      );
      expect(
        palettesFor(ThemeFamilyId.sistema, systemArgb: blue),
        palettesFor(ThemeFamilyId.sistema, systemArgb: blue),
      );
    });
  });

  group('Personalizado (ADR 0036)', () {
    const red = 0xFFD32F2F;

    test(
      'elegir un color activa el tema y la paleta sale de ese color',
      () async {
        final port = _FakePort();
        final container = _container(port);
        await container.read(appearanceControllerProvider.future);

        await container
            .read(appearanceControllerProvider.notifier)
            .setCustomColor(red);

        expect(port.stored.family, ThemeFamilyId.personalizado);
        expect(port.stored.customColorArgb, red);
        final themes = await _themes(container);
        expect(
          _palette(themes.light),
          LockspirePalette.fromSeed(const Color(red), Brightness.light),
        );
      },
    );

    test('un color con transparencia se guarda opaco', () async {
      final port = _FakePort();
      final container = _container(port);
      await container.read(appearanceControllerProvider.future);

      await container
          .read(appearanceControllerProvider.notifier)
          .setCustomColor(0x80D32F2F);

      expect(port.stored.customColorArgb, red);
    });

    test('el color se conserva al pasar a otro tema y volver', () async {
      final port = _FakePort();
      final container = _container(port);
      await container.read(appearanceControllerProvider.future);
      final controller = container.read(appearanceControllerProvider.notifier);

      await controller.setCustomColor(red);
      await controller.setFamily(ThemeFamilyId.grafito);
      await controller.setFamily(ThemeFamilyId.personalizado);

      expect(port.stored.customColorArgb, red);
    });
  });
}
