// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Gabriel Ángel Montoya Rico

import 'dart:typed_data';

import 'package:lockspire/features/sync/domain/ports/sync_port.dart';
import 'package:lockspire/features/sync/domain/ports/sync_state_port.dart';
import 'package:lockspire/features/vault/domain/ports/crypto_port.dart';
import 'package:lockspire/features/vault/domain/ports/master_password_change_replica_port.dart';
import 'package:lockspire/features/vault/domain/ports/vault_storage_port.dart';
import 'package:lockspire/features/vault/domain/vault_file_codec.dart';

import 'sync_vault_use_case.dart';

/// [MasterPasswordChangeReplicaPort] sobre la sync (ADR 0018). Con
/// [remote] `null` (sin proveedor configurado) no hace nada: el cambio es
/// solo local.
class SyncMasterPasswordChangeReplica
    implements MasterPasswordChangeReplicaPort {
  final VaultStoragePort localStorage;
  final VaultStoragePort ancestorStorage;
  final SyncPort? remote;
  final SyncStatePort syncState;
  final CryptoPort crypto;

  const SyncMasterPasswordChangeReplica({
    required this.localStorage,
    required this.ancestorStorage,
    required this.remote,
    required this.syncState,
    required this.crypto,
  });

  @override
  Future<void> syncBeforeChange({
    required Uint8List key,
    required VaultHeader header,
  }) async {
    final remote = this.remote;
    if (remote == null) return;
    await SyncVaultUseCase(
      localStorage: localStorage,
      ancestorStorage: ancestorStorage,
      remote: remote,
      syncState: syncState,
      crypto: crypto,
      key: key,
      header: header,
    ).call();
  }

  @override
  Future<void> publish(VaultFile rekeyed) async {
    final remote = this.remote;
    if (remote == null) return;
    await remote.uploadVault(rekeyed);
    await syncState.saveLastSyncedHash(VaultFileCodec.sha256Hex(rekeyed));
    await ancestorStorage.write(rekeyed);
  }
}
