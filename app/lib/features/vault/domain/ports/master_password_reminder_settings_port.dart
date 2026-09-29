// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Gabriel Ángel Montoya Rico

import '../master_password_reminder.dart';

/// Dónde se guarda cada cuánto se exige la contraseña maestra (ADR 0017).
abstract interface class MasterPasswordReminderSettingsPort {
  /// Nunca lanza: sin valor o ilegible devuelve
  /// [MasterPasswordReminder.defaultValue].
  Future<MasterPasswordReminder> load();

  Future<void> save(MasterPasswordReminder reminder);
}
