// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Lockspire

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../domain/ports/password_unlock_history_port.dart';

const _key = 'session.last_password_unlock';

/// [PasswordUnlockHistoryPort] sobre `flutter_secure_storage`. Guarda la
/// fecha en UTC (ISO 8601): un cambio de zona horaria no mueve el plazo.
class SecureStoragePasswordUnlockHistoryAdapter
    implements PasswordUnlockHistoryPort {
  final FlutterSecureStorage _storage;

  const SecureStoragePasswordUnlockHistoryAdapter(this._storage);

  @override
  Future<DateTime?> lastPasswordUnlock() async {
    try {
      final stored = await _storage.read(key: _key);
      return stored == null ? null : DateTime.tryParse(stored);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> recordPasswordUnlock(DateTime at) =>
      _storage.write(key: _key, value: at.toUtc().toIso8601String());
}
