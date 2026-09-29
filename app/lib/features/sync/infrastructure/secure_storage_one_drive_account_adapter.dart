// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Gabriel Ángel Montoya Rico

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../domain/ports/one_drive_account_port.dart';

const _keyOneDriveEmail = 'sync.one_drive.email';
const _keyOneDriveRefreshToken = 'sync.one_drive.refresh_token';

/// [OneDriveAccountPort].
/// Sobre el almacenamiento seguro del sistema (nunca texto plano en disco).
/// Las claves son las mismas que antes de separar los adaptadores (hallazgo
/// A6), así se conserva lo que ya estaba guardado.
class SecureStorageOneDriveAccountAdapter implements OneDriveAccountPort {
  final FlutterSecureStorage _storage;

  const SecureStorageOneDriveAccountAdapter(this._storage);

  @override
  Future<OneDriveAccount?> oneDriveAccount() async {
    final email = await _storage.read(key: _keyOneDriveEmail);
    final refreshToken = await _storage.read(key: _keyOneDriveRefreshToken);
    if (email == null || refreshToken == null) return null;
    return OneDriveAccount(email: email, refreshToken: refreshToken);
  }

  @override
  Future<void> saveOneDriveAccount(OneDriveAccount account) async {
    await _storage.write(key: _keyOneDriveEmail, value: account.email);
    await _storage.write(
      key: _keyOneDriveRefreshToken,
      value: account.refreshToken,
    );
  }

  @override
  Future<void> clearOneDriveAccount() async {
    await _storage.delete(key: _keyOneDriveEmail);
    await _storage.delete(key: _keyOneDriveRefreshToken);
  }
}
