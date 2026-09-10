// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Lockspire

import 'package:lockspire/features/sync/domain/ports/sync_port.dart';
import 'package:lockspire/features/sync/domain/ports/sync_state_port.dart';
import 'package:lockspire/features/vault/domain/ports/vault_storage_port.dart';
import 'package:lockspire/features/vault/domain/vault_file_codec.dart';

/// Resultado de una sincronización. Ver
/// docs/adr/0006-modelo-resolucion-conflictos.md.
sealed class SyncResult {
  const SyncResult();
}

/// Solo el local tenía cambios (o solo existía local) — se subió.
class SyncUploaded extends SyncResult {
  const SyncUploaded();
}

/// Solo el remoto tenía cambios (o solo existía remoto) — se bajó.
class SyncDownloaded extends SyncResult {
  const SyncDownloaded();
}

/// Local y remoto ya coincidían — no hizo falta hacer nada.
class SyncUpToDate extends SyncResult {
  const SyncUpToDate();
}

/// Cambiaron los dos lados desde la última sync conocida — conflicto real.
/// No se toca ni local ni remoto. El merge automático por entrada
/// (ADR 0006) es una pasada futura; por ahora se resuelve manualmente
/// desde la UI (elegir una copia u otra).
class SyncConflict extends SyncResult {
  const SyncConflict();
}

/// Sincroniza la bóveda local con el proveedor remoto configurado.
///
/// Primera pasada de sync (ver docs/STATE.md): detecta con seguridad si
/// hubo cambios en un solo lado o en los dos desde la última sync, pero
/// todavía no hace el merge automático por entrada del ADR 0006 — ante un
/// conflicto real, no sobrescribe nada en ninguna dirección.
class SyncVaultUseCase {
  final VaultStoragePort localStorage;
  final SyncPort remote;
  final SyncStatePort syncState;

  const SyncVaultUseCase({
    required this.localStorage,
    required this.remote,
    required this.syncState,
  });

  Future<SyncResult> call() async {
    final localExists = await localStorage.exists();
    final remoteExists = await remote.remoteVaultExists();

    if (!localExists && !remoteExists) {
      throw StateError('No hay bóveda ni local ni remota para sincronizar');
    }

    if (!remoteExists) {
      final local = await localStorage.read();
      await remote.uploadVault(local);
      await syncState.saveLastSyncedHash(VaultFileCodec.sha256Hex(local));
      return const SyncUploaded();
    }

    if (!localExists) {
      final remoteFile = await remote.downloadVault();
      await localStorage.write(remoteFile);
      await syncState.saveLastSyncedHash(VaultFileCodec.sha256Hex(remoteFile));
      return const SyncDownloaded();
    }

    final local = await localStorage.read();
    final remoteFile = await remote.downloadVault();
    final localHash = VaultFileCodec.sha256Hex(local);
    final remoteHash = VaultFileCodec.sha256Hex(remoteFile);

    if (localHash == remoteHash) {
      await syncState.saveLastSyncedHash(localHash);
      return const SyncUpToDate();
    }

    final lastSynced = await syncState.lastSyncedHash();
    final localChanged = lastSynced != localHash;
    final remoteChanged = lastSynced != remoteHash;

    if (localChanged && !remoteChanged) {
      await remote.uploadVault(local);
      await syncState.saveLastSyncedHash(localHash);
      return const SyncUploaded();
    }

    if (remoteChanged && !localChanged) {
      await localStorage.write(remoteFile);
      await syncState.saveLastSyncedHash(remoteHash);
      return const SyncDownloaded();
    }

    // Cambiaron los dos (o no había hash previo y ya difieren de entrada):
    // conflicto real, no se toca nada.
    return const SyncConflict();
  }
}
