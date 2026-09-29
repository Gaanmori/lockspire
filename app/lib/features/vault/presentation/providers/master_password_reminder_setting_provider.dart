// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Gabriel Ángel Montoya Rico

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../domain/master_password_reminder.dart';
import 'master_password_reminder_settings_port_provider.dart';

part 'master_password_reminder_setting_provider.g.dart';

/// Cada cuánto se exige la contraseña maestra (ADR 0017), elegido en
/// Seguridad.
@Riverpod(keepAlive: true)
class MasterPasswordReminderSetting extends _$MasterPasswordReminderSetting {
  @override
  Future<MasterPasswordReminder> build() =>
      ref.watch(masterPasswordReminderSettingsPortProvider).load();

  /// Se aplica al instante; si guardar falla, dura hasta cerrar la app.
  Future<void> set(MasterPasswordReminder reminder) async {
    state = AsyncData(reminder);
    try {
      await ref.read(masterPasswordReminderSettingsPortProvider).save(reminder);
    } catch (_) {}
  }
}
