// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Lockspire

import 'package:lockspire/features/vault/domain/ports/master_password_change_replica_port.dart';
import 'package:lockspire/features/vault/presentation/providers/crypto_port_provider.dart';
import 'package:lockspire/features/vault/presentation/providers/vault_storage_port_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../application/sync_master_password_change_replica.dart';
import 'active_sync_port_provider.dart';
import 'sync_ancestor_storage_port_provider.dart';
import 'sync_state_port_provider.dart';

part 'master_password_change_replica_port_provider.g.dart';

/// Composition root de [MasterPasswordChangeReplicaPort] (ADR 0018). Se
/// reconstruye solo cuando cambia el proveedor de sync activo.
@Riverpod(keepAlive: true)
Future<MasterPasswordChangeReplicaPort> masterPasswordChangeReplicaPort(
  Ref ref,
) async {
  return SyncMasterPasswordChangeReplica(
    localStorage: await ref.watch(vaultStoragePortProvider.future),
    ancestorStorage: await ref.watch(syncAncestorStoragePortProvider.future),
    remote: await ref.watch(activeSyncPortProvider.future),
    syncState: ref.watch(syncStatePortProvider),
    crypto: await ref.watch(cryptoPortProvider.future),
  );
}
