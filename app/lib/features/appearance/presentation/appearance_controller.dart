// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Gabriel Ángel Montoya Rico

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../domain/appearance_preference.dart';
import 'providers/appearance_preferences_port_provider.dart';

part 'appearance_controller.g.dart';

/// Preferencia de tema activa. `main()` la carga antes de pintar el primer
/// frame para no mostrar un instante el tema por defecto. Para convertirla
/// en `ThemeData` ver `appearance_theme.dart`.
@Riverpod(keepAlive: true)
class AppearanceController extends _$AppearanceController {
  @override
  Future<AppearancePreference> build() =>
      ref.watch(appearancePreferencesPortProvider).load();

  Future<void> setFamily(ThemeFamilyId family) =>
      _update(_current.copyWith(family: family));

  Future<void> setMode(AppearanceMode mode) =>
      _update(_current.copyWith(mode: mode));

  Future<void> setLanguage(AppLanguage language) =>
      _update(_current.copyWith(language: language));

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
