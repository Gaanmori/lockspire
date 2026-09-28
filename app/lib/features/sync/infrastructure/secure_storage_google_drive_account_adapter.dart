// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Lockspire

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../domain/ports/google_drive_account_port.dart';

const _keyGoogleDriveEmail = 'sync.google_drive.email';
const _keyGoogleDriveRefreshToken = 'sync.google_drive.refresh_token';

/// [GoogleDriveAccountPort].
/// Sobre el almacenamiento seguro del sistema (nunca texto plano en disco).
/// Las claves son las mismas que antes de separar los adaptadores (hallazgo
/// A6), así se conserva lo que ya estaba guardado.
class SecureStorageGoogleDriveAccountAdapter implements GoogleDriveAccountPort {
  final FlutterSecureStorage _storage;

  const SecureStorageGoogleDriveAccountAdapter(this._storage);

  @override
  Future<GoogleDriveAccount?> googleDriveAccount() async {
    final email = await _storage.read(key: _keyGoogleDriveEmail);
    if (email == null) return null;
    final refreshToken = await _storage.read(key: _keyGoogleDriveRefreshToken);
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
