// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Lockspire

import 'package:riverpod_annotation/riverpod_annotation.dart';

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
    try {
      await ref.read(autoLockPreferencesPortProvider).save(timeout);
    } catch (_) {}
  }
}
