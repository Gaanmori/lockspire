// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Lockspire

import 'dart:typed_data';

import 'package:lockspire/features/sync/domain/ports/sync_port.dart';
import 'package:lockspire/features/sync/domain/ports/sync_state_port.dart';
import 'package:lockspire/features/sync/domain/vault_merge.dart';
import 'package:lockspire/features/vault/application/save_vault_use_case.dart';
import 'package:lockspire/features/vault/domain/entities/vault.dart';
import 'package:lockspire/features/vault/domain/entities/vault_entry.dart';
import 'package:lockspire/features/vault/domain/ports/crypto_port.dart';
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

/// Cambiaron los dos lados, pero el merge automático por entrada (ADR
/// 0006) pudo resolver todo solo (ediciones en un solo lado, tombstones) —
/// [autoResolvedCount] entradas resueltas sin intervención del usuario.
class SyncMerged extends SyncResult {
  final int autoResolvedCount;
  const SyncMerged({required this.autoResolvedCount});
}

/// Cambiaron los dos lados y al menos una entrada cambió distinto de
/// verdad en cada lado — conflicto real que solo puede resolver el
/// usuario (picker manual, ver `ConflictResolutionScreen`). **No se
/// escribió ni subió nada todavía** — [autoMerged]/[conflicts] quedan acá
/// para que la UI junte las resoluciones y llame
/// `SyncVaultUseCase.completeMerge`.
class SyncNeedsResolution extends SyncResult {
  final Vault autoMerged;
  final List<EntryConflict> conflicts;
  final int autoResolvedCount;
  final String localHashAtAnalysis;
  final String remoteHashAtAnalysis;

  const SyncNeedsResolution({
    required this.autoMerged,
    required this.conflicts,
    required this.autoResolvedCount,
    required this.localHashAtAnalysis,
    required this.remoteHashAtAnalysis,
  });
}

/// Lanzada por [SyncVaultUseCase.completeMerge] si el local o el remoto
/// cambiaron de nuevo mientras el usuario tenía el picker de conflictos
/// abierto — nunca se sube un merge calculado sobre datos que ya
/// quedaron viejos. El llamador debe volver a sincronizar desde cero
/// (`call()`), no reintentar `completeMerge` con la misma resolución.
class SyncStaleMergeException implements Exception {
  @override
  String toString() =>
      'La bóveda cambió (local o remota) mientras se resolvían los '
      'conflictos — hay que volver a sincronizar.';
}

/// Sincroniza la bóveda local con el proveedor remoto configurado,
/// resolviendo automáticamente lo que se pueda (ADR 0006) y devolviendo
/// los conflictos reales para que la UI los resuelva con el usuario.
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

    // Cambiaron los dos: merge de 3 vías (ADR 0006).
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

    if (!analysis.hasConflicts) {
      await _saveAndUpload(analysis.autoMerged);
      return SyncMerged(autoResolvedCount: analysis.autoResolvedCount);
    }

    return SyncNeedsResolution(
      autoMerged: analysis.autoMerged,
      conflicts: analysis.conflicts,
      autoResolvedCount: analysis.autoResolvedCount,
      localHashAtAnalysis: localHash,
      remoteHashAtAnalysis: remoteHash,
    );
  }

  /// Segundo paso tras [SyncNeedsResolution]: aplica lo que el usuario
  /// eligió para cada conflicto y termina la sincronización. Antes de
  /// escribir, vuelve a comprobar que ni local ni remoto cambiaron desde
  /// el análisis — si cambiaron, lanza [SyncStaleMergeException] sin
  /// escribir nada (ver ese comentario para el porqué).
  Future<SyncResult> completeMerge(
    SyncNeedsResolution pending,
    Map<String, VaultEntry> resolutions,
  ) async {
    final currentLocal = await localStorage.read();
    final currentRemoteFile = await remote.downloadVault();
    final currentLocalHash = VaultFileCodec.sha256Hex(currentLocal);
    final currentRemoteHash = VaultFileCodec.sha256Hex(currentRemoteFile);

    if (currentLocalHash != pending.localHashAtAnalysis ||
        currentRemoteHash != pending.remoteHashAtAnalysis) {
      throw SyncStaleMergeException();
    }

    final merged = applyConflictResolutions(pending.autoMerged, resolutions);
    await _saveAndUpload(merged);
    return SyncMerged(autoResolvedCount: pending.autoResolvedCount);
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
