// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Gabriel Ángel Montoya Rico

import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:lockspire/shared/presentation/preferences.dart';

import '../../domain/auto_lock_timeout.dart';
import 'auto_lock_preferences_port_provider.dart';

part 'auto_lock_timeout_setting_provider.g.dart';

/// Tiempo de bloqueo elegido por el usuario (ADR 0016). `main()` lo carga
/// antes del primer frame, así el primer desbloqueo ya usa el valor
/// guardado.
@Riverpod(keepAlive: true)
class AutoLockTimeoutSetting extends _$AutoLockTimeoutSetting {
  @override
  Future<AutoLockTimeout> build() =>
      ref.watch(autoLockPreferencesPortProvider).load();

  /// Se aplica al instante; si guardar falla, dura hasta cerrar la app.
  Future<void> set(AutoLockTimeout timeout) async {
    state = AsyncData(timeout);
    await saveAppliedPreference(
      () => ref.read(autoLockPreferencesPortProvider).save(timeout),
    );
  }
}
