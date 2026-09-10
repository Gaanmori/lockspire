// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Lockspire

import 'dart:typed_data';

import 'package:lockspire/features/sync/domain/ports/sync_port.dart';
import 'package:lockspire/features/sync/domain/ports/sync_state_port.dart';
import 'package:lockspire/features/sync/domain/vault_merge.dart';
import 'package:lockspire/features/vault/application/save_vault_use_case.dart';
import 'package:lockspire/features/vault/domain/entities/vault.dart';
import 'package:lockspire/features/vault/domain/ports/crypto_port.dart';
import 'package:lockspire/features/vault/domain/ports/vault_storage_port.dart';
import 'package:lockspire/features/vault/domain/vault_file_codec.dart';

/// Resultado de una sincronización. Ver
/// docs/adr/0006-modelo-resolucion-conflictos.md y
/// docs/adr/0009-merge-automatico-por-campo.md.
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

/// Cambiaron los dos lados — el merge automático (por entrada, ADR 0006, y
/// por campo cuando hace falta, ADR 0009) resolvió todo solo, sin
/// intervención del usuario. [autoResolvedCount] son entradas completas
/// resueltas porque solo cambió un lado o fue un tombstone;
/// [fieldConflictsResolved] son campos individuales que chocaron de
/// verdad en ambos lados y se resolvieron automáticamente (el valor
/// perdedor queda en `VaultEntry.fieldHistory` de esa entrada).
class SyncMerged extends SyncResult {
  final int autoResolvedCount;
  final int fieldConflictsResolved;

  const SyncMerged({
    required this.autoResolvedCount,
    required this.fieldConflictsResolved,
  });
}

/// Sincroniza la bóveda local con el proveedor remoto configurado,
/// resolviendo automáticamente todo lo que haga falta (ADR 0006 + ADR
/// 0009) — nunca deja nada pendiente de que el usuario decida.
class SyncVaultUseCase {
  final VaultStoragePort localStorage;
  final VaultStoragePort ancestorStorage;
  final SyncPort remote;
  final SyncStatePort syncState;
  final CryptoPort crypto;
  final Uint8List key;
  final VaultHeader header;

  const SyncVaultUseCase({
    required this.localStorage,
    required this.ancestorStorage,
    required this.remote,
    required this.syncState,
    required this.crypto,
    required this.key,
    required this.header,
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
      await _markSynced(local);
      return const SyncUploaded();
    }

    if (!localExists) {
      final remoteFile = await remote.downloadVault();
      await localStorage.write(remoteFile);
      await _markSynced(remoteFile);
      return const SyncDownloaded();
    }

    final local = await localStorage.read();
    final remoteFile = await remote.downloadVault();
    final localHash = VaultFileCodec.sha256Hex(local);
    final remoteHash = VaultFileCodec.sha256Hex(remoteFile);

    if (localHash == remoteHash) {
      await _markSynced(local);
      return const SyncUpToDate();
    }

    final lastSynced = await syncState.lastSyncedHash();
    final localChanged = lastSynced != localHash;
    final remoteChanged = lastSynced != remoteHash;

    if (localChanged && !remoteChanged) {
      await remote.uploadVault(local);
      await _markSynced(local);
      return const SyncUploaded();
    }

    if (remoteChanged && !localChanged) {
      await localStorage.write(remoteFile);
      await _markSynced(remoteFile);
      return const SyncDownloaded();
    }

    // Cambiaron los dos: merge de 3 vías (ADR 0006) + merge por campo para
    // cualquier choque real (ADR 0009) — siempre termina resuelto, nunca
    // hace falta un segundo paso.
    final ancestorFile = await ancestorStorage.exists()
        ? await ancestorStorage.read()
        : null;
    final localVault = await _decrypt(local);
    final remoteVault = await _decrypt(remoteFile);
    final ancestorVault = ancestorFile != null
        ? await _decrypt(ancestorFile)
        : null;

    final analysis = mergeVaults(
      ancestor: ancestorVault,
      local: localVault,
      remote: remoteVault,
    );

    await _saveAndUpload(analysis.autoMerged);
    return SyncMerged(
      autoResolvedCount: analysis.autoResolvedCount,
      fieldConflictsResolved: analysis.fieldConflictsResolved,
    );
  }

  Future<VaultFile> _saveAndUpload(Vault vault) async {
    final written = await SaveVaultUseCase(
      storage: localStorage,
      crypto: crypto,
    ).saveInitial(vault: vault, key: key, header: header);
    await remote.uploadVault(written);
    await _markSynced(written);
    return written;
  }

  Future<void> _markSynced(VaultFile file) async {
    await syncState.saveLastSyncedHash(VaultFileCodec.sha256Hex(file));
    await ancestorStorage.write(file);
  }

  Future<Vault> _decrypt(VaultFile file) async {
    final plaintext = await crypto.decrypt(
      key: key,
      payload: EncryptedPayload(
        nonce: file.header.nonce,
        ciphertext: file.encryptedPayload,
      ),
      aad: file.header.toAadBytes(),
    );
    return Vault.fromJsonBytes(plaintext);
  }
}
