// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Lockspire

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../domain/ports/sync_state_port.dart';

const _keyLastSyncedHash = 'sync.last_synced_hash';

/// [SyncStatePort] (hash del último archivo sincronizado).
/// Sobre el almacenamiento seguro del sistema (nunca texto plano en disco).
/// Las claves son las mismas que antes de separar los adaptadores (hallazgo
/// A6), así se conserva lo que ya estaba guardado.
class SecureStorageSyncStateAdapter implements SyncStatePort {
  final FlutterSecureStorage _storage;

  const SecureStorageSyncStateAdapter(this._storage);

  @override
  Future<String?> lastSyncedHash() => _storage.read(key: _keyLastSyncedHash);

  @override
  Future<void> saveLastSyncedHash(String hash) =>
      _storage.write(key: _keyLastSyncedHash, value: hash);
}
