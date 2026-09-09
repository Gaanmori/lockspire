// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Lockspire

import 'package:lockspire/features/sync/domain/ports/sync_port.dart';
import 'package:lockspire/features/sync/domain/ports/sync_state_port.dart';
import 'package:lockspire/features/vault/domain/ports/vault_storage_port.dart';

/// Remoto falso en memoria para tests — no hace red real.
class FakeSyncPort implements SyncPort {
  VaultFile? remoteFile;

  @override
  Future<bool> remoteVaultExists() async => remoteFile != null;

  @override
  Future<VaultFile> downloadVault() async {
    final file = remoteFile;
    if (file == null) {
      throw StateError('No hay bóveda remota');
    }
    return file;
  }

  @override
  Future<void> uploadVault(VaultFile file) async {
    remoteFile = file;
  }
}

/// Estado de sync falso en memoria para tests.
class FakeSyncStatePort implements SyncStatePort {
  String? _lastSyncedHash;

  @override
  Future<String?> lastSyncedHash() async => _lastSyncedHash;

  @override
  Future<void> saveLastSyncedHash(String hash) async {
    _lastSyncedHash = hash;
  }
}
