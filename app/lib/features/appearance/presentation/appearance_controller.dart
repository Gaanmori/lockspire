// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Lockspire

import 'package:flutter/material.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../design/lockspire_theme.dart';
import '../domain/appearance_preference.dart';
import '../domain/ports/appearance_preferences_port.dart';
import '../infrastructure/secure_storage_appearance_adapter.dart';

part 'appearance_controller.g.dart';

@Riverpod(keepAlive: true)
AppearancePreferencesPort appearancePreferencesPort(Ref ref) =>
    const SecureStorageAppearanceAdapter();

/// Preferencia de tema activa. `main()` la carga antes de pintar el primer
/// frame para no mostrar un instante el tema por defecto.
@Riverpod(keepAlive: true)
class AppearanceController extends _$AppearanceController {
  @override
  Future<AppearancePreference> build() =>
      ref.watch(appearancePreferencesPortProvider).load();

  Future<void> setFamily(ThemeFamilyId family) =>
      _update(_current.copyWith(family: family));

  Future<void> setMode(AppearanceMode mode) =>
      _update(_current.copyWith(mode: mode));

  AppearancePreference get _current =>
      state.value ?? AppearancePreference.defaults;

  Future<void> _update(AppearancePreference next) async {
    // Se aplica de inmediato; si guardar falla, el tema dura hasta cerrar
    // la app (no vale la pena interrumpir al usuario por esto).
    state = AsyncData(next);
    try {
      await ref.read(appearancePreferencesPortProvider).save(next);
    } catch (_) {}
  }
}

/// Traducciones de la preferencia de dominio a tipos de Flutter.
extension AppearancePreferenceTheme on AppearancePreference {
  LockspireThemeFamily get themeFamily =>
      LockspireThemeFamily.values.byName(family.name);

  ThemeData get lightTheme => LockspireTheme.of(themeFamily.light);

  ThemeData get darkTheme => LockspireTheme.of(themeFamily.dark);

  ThemeMode get themeMode => switch (mode) {
    AppearanceMode.system => ThemeMode.system,
    AppearanceMode.light => ThemeMode.light,
    AppearanceMode.dark => ThemeMode.dark,
  };
}
