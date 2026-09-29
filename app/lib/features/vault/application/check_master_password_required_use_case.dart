// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Gabriel Ángel Montoya Rico

import '../domain/master_password_reminder.dart';
import '../domain/ports/master_password_reminder_settings_port.dart';
import '../domain/ports/password_unlock_history_port.dart';

/// ¿Hay que pedir la contraseña maestra en vez de ofrecer biometría? (ADR
/// 0017).
///
/// Se evalúa **en cada llamada** con los datos persistidos y la hora
/// actual, nunca desde un valor cacheado. Si fuera un provider de Riverpod
/// con el resultado, podría quedar obsoleto (la app abierta en la bandeja
/// mientras vence el plazo) o descartarse a mitad de la lectura si nadie
/// lo escucha. Ese segundo caso fue un bug real: la app nunca ofrecía
/// Windows Hello.
class CheckMasterPasswordRequiredUseCase {
  final MasterPasswordReminderSettingsPort _settings;
  final PasswordUnlockHistoryPort _history;
  final DateTime Function() _now;

  const CheckMasterPasswordRequiredUseCase({
    required this._settings,
    required this._history,
    required this._now,
  });

  /// Nunca lanza: si algo falla al leer, exige la contraseña (el lado
  /// seguro).
  Future<bool> call() async {
    try {
      final reminder = await _settings.load();
      final last = await _history.lastPasswordUnlock();
      return isMasterPasswordRequiredAt(
        lastPasswordUnlock: last,
        now: _now(),
        interval: reminder.interval,
      );
    } catch (_) {
      return true;
    }
  }
}
