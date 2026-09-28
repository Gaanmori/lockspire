// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Lockspire

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../domain/ports/sync_credentials_port.dart';

const _keyServerUrl = 'sync.webdav.server_url';
const _keyUsername = 'sync.webdav.username';
const _keyPassword = 'sync.webdav.password';
// Olvidar las credenciales también olvida la última sync: sin servidor,
// ese estado ya no significa nada. Misma clave que SecureStorageSyncStateAdapter.
const _keyLastSyncedHash = 'sync.last_synced_hash';

/// [SyncCredentialsPort] (credenciales de WebDAV).
/// Sobre el almacenamiento seguro del sistema (nunca texto plano en disco).
/// Las claves son las mismas que antes de separar los adaptadores (hallazgo
/// A6), así se conserva lo que ya estaba guardado.
class SecureStorageSyncCredentialsAdapter implements SyncCredentialsPort {
  final FlutterSecureStorage _storage;

  const SecureStorageSyncCredentialsAdapter(this._storage);

  @override
  Future<WebDavCredentials?> read() async {
    final serverUrl = await _storage.read(key: _keyServerUrl);
    final username = await _storage.read(key: _keyUsername);
    final password = await _storage.read(key: _keyPassword);
    if (serverUrl == null || username == null || password == null) {
      return null;
    }
    return WebDavCredentials(
      serverUrl: serverUrl,
      username: username,
      password: password,
    );
  }

  @override
  Future<void> save(WebDavCredentials credentials) async {
    await _storage.write(key: _keyServerUrl, value: credentials.serverUrl);
    await _storage.write(key: _keyUsername, value: credentials.username);
    await _storage.write(key: _keyPassword, value: credentials.password);
  }

  @override
  Future<void> clear() async {
    await _storage.delete(key: _keyServerUrl);
    await _storage.delete(key: _keyUsername);
    await _storage.delete(key: _keyPassword);
    await _storage.delete(key: _keyLastSyncedHash);
  }
}
