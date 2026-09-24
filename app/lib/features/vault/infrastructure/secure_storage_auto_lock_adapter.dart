// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Lockspire

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../domain/auto_lock_timeout.dart';
import '../domain/ports/auto_lock_preferences_port.dart';

const _key = 'session.auto_lock_timeout';

/// [AutoLockPreferencesPort] sobre `flutter_secure_storage`, el mismo
/// almacenamiento que el resto de preferencias de la app.
class SecureStorageAutoLockAdapter implements AutoLockPreferencesPort {
  final FlutterSecureStorage _storage;

  const SecureStorageAutoLockAdapter([
    this._storage = const FlutterSecureStorage(),
  ]);

  @override
  Future<AutoLockTimeout> load() async {
    try {
      final stored = await _storage.read(key: _key);
      return AutoLockTimeout.values
              .where((t) => t.name == stored)
              .firstOrNull ??
          AutoLockTimeout.defaultValue;
    } catch (_) {
      // Keyring no disponible o tests sin plugin: el valor por defecto.
      return AutoLockTimeout.defaultValue;
    }
  }

  @override
  Future<void> save(AutoLockTimeout timeout) =>
      _storage.write(key: _key, value: timeout.name);
}
