// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Lockspire

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lockspire/design/lockspire_colors.dart';
import 'package:lockspire/features/appearance/domain/appearance_preference.dart';
import 'package:lockspire/features/appearance/domain/ports/appearance_preferences_port.dart';
import 'package:lockspire/features/appearance/presentation/appearance_controller.dart';
import 'package:lockspire/features/appearance/presentation/appearance_theme.dart';
import 'package:lockspire/features/appearance/presentation/providers/appearance_preferences_port_provider.dart';

class _FakePort implements AppearancePreferencesPort {
  AppearancePreference stored;
  final saved = <AppearancePreference>[];

  _FakePort([this.stored = AppearancePreference.defaults]);

  @override
  Future<AppearancePreference> load() async => stored;

  @override
  Future<void> save(AppearancePreference preference) async {
    stored = preference;
    saved.add(preference);
  }
}

ProviderContainer _container(_FakePort port) {
  final container = ProviderContainer(
    overrides: [appearancePreferencesPortProvider.overrideWithValue(port)],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  test('sin nada guardado: Cálido, según el sistema', () async {
    final container = _container(_FakePort());
    final pref = await container.read(appearanceControllerProvider.future);
    expect(pref, AppearancePreference.defaults);
    expect(pref.themeMode, ThemeMode.system);
    expect(
      pref.lightTheme.extension<LockspirePalette>(),
      LockspirePalettes.calido,
    );
    expect(
      pref.darkTheme.extension<LockspirePalette>(),
      LockspirePalettes.calidoOscuro,
    );
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
    final pref = await container.read(appearanceControllerProvider.future);
    expect(pref.themeMode, ThemeMode.dark);
    expect(
      pref.darkTheme.extension<LockspirePalette>(),
      LockspirePalettes.lavandaOscuro,
    );
  });

  test('cambiar familia y modo se aplica y se guarda', () async {
    final port = _FakePort();
    final container = _container(port);
    await container.read(appearanceControllerProvider.future);
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
      container
          .read(appearanceControllerProvider)
          .value!
          .lightTheme
          .extension<LockspirePalette>(),
      LockspirePalettes.menta,
    );
  });
}
