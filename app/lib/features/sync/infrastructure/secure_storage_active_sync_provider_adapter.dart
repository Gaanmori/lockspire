// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Gabriel Ángel Montoya Rico

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../domain/ports/active_sync_provider_port.dart';

const _keyActiveProvider = 'sync.active_provider';

/// [ActiveSyncProviderPort] (qué proveedor de sync está activo).
/// Sobre el almacenamiento seguro del sistema (nunca texto plano en disco).
/// Las claves son las mismas que antes de separar los adaptadores (hallazgo
/// A6), así se conserva lo que ya estaba guardado.
class SecureStorageActiveSyncProviderAdapter implements ActiveSyncProviderPort {
  final FlutterSecureStorage _storage;

  const SecureStorageActiveSyncProviderAdapter(this._storage);

  @override
  Future<SyncProviderId?> activeProvider() async {
    final value = await _storage.read(key: _keyActiveProvider);
    return switch (value) {
      'webdav' => SyncProviderId.webdav,
      'googleDrive' => SyncProviderId.googleDrive,
      'oneDrive' => SyncProviderId.oneDrive,
      _ => null,
    };
  }

  @override
  Future<void> saveActiveProvider(SyncProviderId id) =>
      _storage.write(key: _keyActiveProvider, value: id.name);

  @override
  Future<void> clearActiveProvider() =>
      _storage.delete(key: _keyActiveProvider);
}
