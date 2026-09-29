// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Gabriel Ángel Montoya Rico

import 'dart:typed_data';

import 'package:lockspire/features/vault/domain/ports/master_password_change_replica_port.dart';
import 'package:lockspire/features/vault/domain/ports/vault_storage_port.dart';
import 'package:lockspire/features/vault/presentation/providers/crypto_port_provider.dart';
import 'package:lockspire/features/vault/presentation/providers/vault_storage_port_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../application/sync_master_password_change_replica.dart';
import 'active_sync_port_provider.dart';
import 'sync_ancestor_storage_port_provider.dart';
import 'sync_state_port_provider.dart';

part 'sync_master_password_change_replica_provider.g.dart';

/// Implementación de [MasterPasswordChangeReplicaPort] sobre la sync (ADR
/// 0018). La app la conecta al puerto de `vault` en
/// `lib/app_composition.dart` (hallazgo A3). Se reconstruye cuando cambia
/// el proveedor de sync activo.
@Riverpod(keepAlive: true)
Future<MasterPasswordChangeReplicaPort> syncMasterPasswordChangeReplica(
  Ref ref,
) async {
  final localStorage = await ref.watch(vaultStoragePortProvider.future);
  final ancestorStorage = await ref.watch(
    syncAncestorStoragePortProvider.future,
  );
  final crypto = await ref.watch(cryptoPortProvider.future);
  return _FreshRemoteReplica(
    () async => SyncMasterPasswordChangeReplica(
      localStorage: localStorage,
      ancestorStorage: ancestorStorage,
      remote: await freshActiveSyncPort(ref),
      syncState: ref.read(syncStatePortProvider),
      crypto: crypto,
    ),
  );
}

/// Arma la réplica con un token fresco en cada operación: el cambio de
/// contraseña puede llegar horas después de abrir la app (ver
/// [freshActiveSyncPort]).
class _FreshRemoteReplica implements MasterPasswordChangeReplicaPort {
  final Future<SyncMasterPasswordChangeReplica> Function() _build;

  _FreshRemoteReplica(this._build);

  @override
  Future<void> syncBeforeChange({
    required Uint8List key,
    required VaultHeader header,
  }) async => (await _build()).syncBeforeChange(key: key, header: header);

  @override
  Future<void> publish(VaultFile rekeyed) async =>
      (await _build()).publish(rekeyed);
}
