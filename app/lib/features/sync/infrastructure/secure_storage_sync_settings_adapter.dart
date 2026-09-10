// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Lockspire

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../domain/ports/active_sync_provider_port.dart';
import '../domain/ports/google_drive_account_port.dart';
import '../domain/ports/sync_credentials_port.dart';
import '../domain/ports/sync_state_port.dart';

const _keyServerUrl = 'sync.webdav.server_url';
const _keyUsername = 'sync.webdav.username';
const _keyPassword = 'sync.webdav.password';
const _keyLastSyncedHash = 'sync.last_synced_hash';
const _keyActiveProvider = 'sync.active_provider';
const _keyGoogleDriveEmail = 'sync.google_drive.email';
const _keyGoogleDriveRefreshToken = 'sync.google_drive.refresh_token';

/// Implementa [SyncCredentialsPort], [SyncStatePort],
/// [ActiveSyncProviderPort] y [GoogleDriveAccountPort] sobre el
/// almacenamiento seguro del SO (Keystore en Android, Keychain en
/// iOS/macOS, DPAPI en Windows) — nunca texto plano en disco. Un solo
/// adapter para las cuatro interfaces porque comparten el mismo backend y
/// son todas config de sync — no hay razón para instancias separadas.
class SecureStorageSyncSettingsAdapter
    implements
        SyncCredentialsPort,
        SyncStatePort,
        ActiveSyncProviderPort,
        GoogleDriveAccountPort {
  final FlutterSecureStorage _storage;

  const SecureStorageSyncSettingsAdapter(this._storage);

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

  @override
  Future<String?> lastSyncedHash() => _storage.read(key: _keyLastSyncedHash);

  @override
  Future<void> saveLastSyncedHash(String hash) =>
      _storage.write(key: _keyLastSyncedHash, value: hash);

  @override
  Future<SyncProviderId?> activeProvider() async {
    final value = await _storage.read(key: _keyActiveProvider);
    return switch (value) {
      'webdav' => SyncProviderId.webdav,
      'googleDrive' => SyncProviderId.googleDrive,
      _ => null,
    };
  }

  @override
  Future<void> saveActiveProvider(SyncProviderId id) =>
      _storage.write(key: _keyActiveProvider, value: id.name);

  @override
  Future<void> clearActiveProvider() =>
      _storage.delete(key: _keyActiveProvider);

  @override
  Future<GoogleDriveAccount?> googleDriveAccount() async {
    final email = await _storage.read(key: _keyGoogleDriveEmail);
    if (email == null) return null;
    final refreshToken = await _storage.read(
      key: _keyGoogleDriveRefreshToken,
    );
    return GoogleDriveAccount(email: email, refreshToken: refreshToken);
  }

  @override
  Future<void> saveGoogleDriveAccount(GoogleDriveAccount account) async {
    await _storage.write(key: _keyGoogleDriveEmail, value: account.email);
    if (account.refreshToken != null) {
      await _storage.write(
        key: _keyGoogleDriveRefreshToken,
        value: account.refreshToken,
      );
    }
  }

  @override
  Future<void> clearGoogleDriveAccount() async {
    await _storage.delete(key: _keyGoogleDriveEmail);
    await _storage.delete(key: _keyGoogleDriveRefreshToken);
  }
}
