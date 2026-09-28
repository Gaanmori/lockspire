// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Lockspire

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../domain/master_password_reminder.dart';
import '../domain/ports/master_password_reminder_settings_port.dart';

const _key = 'session.master_password_reminder';

/// [MasterPasswordReminderSettingsPort] sobre `flutter_secure_storage`.
class SecureStorageMasterPasswordReminderAdapter
    implements MasterPasswordReminderSettingsPort {
  final FlutterSecureStorage _storage;

  const SecureStorageMasterPasswordReminderAdapter(this._storage);

  @override
  Future<MasterPasswordReminder> load() async {
    try {
      final stored = await _storage.read(key: _key);
      return MasterPasswordReminder.values
              .where((r) => r.name == stored)
              .firstOrNull ??
          MasterPasswordReminder.defaultValue;
    } catch (_) {
      return MasterPasswordReminder.defaultValue;
    }
  }

  @override
  Future<void> save(MasterPasswordReminder reminder) =>
      _storage.write(key: _key, value: reminder.name);
}
