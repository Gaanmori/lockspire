// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Lockspire

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lockspire/design/lockspire_colors.dart';
import 'package:lockspire/features/appearance/domain/appearance_preference.dart';
import 'package:lockspire/features/appearance/domain/ports/appearance_preferences_port.dart';
import 'package:lockspire/features/appearance/domain/ports/system_accent_color_port.dart';
import 'package:lockspire/features/appearance/presentation/appearance_controller.dart';
import 'package:lockspire/features/appearance/presentation/appearance_theme.dart';
import 'package:lockspire/features/appearance/presentation/providers/app_themes_provider.dart';
import 'package:lockspire/features/appearance/presentation/providers/appearance_preferences_port_provider.dart';
import 'package:lockspire/features/appearance/presentation/providers/system_accent_color_provider.dart';

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

class _FakeAccent implements SystemAccentColorPort {
  final int? argb;
  const _FakeAccent(this.argb);

  @override
  Future<int?> accentColorArgb() async => argb;
}

ProviderContainer _container(_FakePort port, {int? systemArgb}) {
  final container = ProviderContainer(
    overrides: [
      appearancePreferencesPortProvider.overrideWithValue(port),
      systemAccentColorPortProvider.overrideWithValue(_FakeAccent(systemArgb)),
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
  test('sin nada guardado: Lineage, según el sistema', () async {
    final container = _container(_FakePort());
    final themes = await _themes(container);
    expect(
      container.read(appearanceControllerProvider).value,
      AppearancePreference.defaults,
    );
    expect(themes.mode, ThemeMode.system);
    expect(_palette(themes.light), LockspirePalettes.lineage);
    expect(_palette(themes.dark), LockspirePalettes.lineageOscuro);
  });

  test('carga lo guardado', () async {
    final container = _container(
      _FakePort(
        const AppearancePreference(
          family: ThemeFamilyId.lavanda,
          mode: AppearanceMode.dark,
        ),
      ),
    );
    final themes = await _themes(container);
    expect(themes.mode, ThemeMode.dark);
    expect(_palette(themes.dark), LockspirePalettes.lavandaOscuro);
  });

  test('cambiar familia y modo se aplica y se guarda', () async {
    final port = _FakePort();
    final container = _container(port);
    await _themes(container);
    final controller = container.read(appearanceControllerProvider.notifier);

    await controller.setFamily(ThemeFamilyId.menta);
    await controller.setMode(AppearanceMode.light);

    const expected = AppearancePreference(
      family: ThemeFamilyId.menta,
      mode: AppearanceMode.light,
    );
    expect(container.read(appearanceControllerProvider).value, expected);
    expect(port.stored, expected);
    expect(
      _palette(container.read(appThemesProvider).light),
      LockspirePalettes.menta,
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

    test('sin color del sistema, usa Lineage', () async {
      final container = _container(
        _FakePort(
          const AppearancePreference(
            family: ThemeFamilyId.sistema,
            mode: AppearanceMode.system,
          ),
        ),
      );
      final themes = await _themes(container);
      expect(_palette(themes.light), LockspirePalettes.lineage);
    });

    test('dos paletas del mismo color son iguales (la caché de temas '
        'las reutiliza)', () {
      expect(
        LockspirePalette.fromSeed(const Color(blue), Brightness.dark),
        LockspirePalette.fromSeed(const Color(blue), Brightness.dark),
      );
      expect(
        palettesFor(ThemeFamilyId.sistema, blue),
        palettesFor(ThemeFamilyId.sistema, blue),
      );
    });
  });
}
