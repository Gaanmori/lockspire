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

/// Por qué se rechazó el archivo remoto.
enum RemoteVaultRejection {
  /// Es otra bóveda (otro `vault_id`).
  differentVault,

  /// No se descifra con la clave de esta sesión: manipulado, dañado o
  /// cifrado con otra contraseña.
  notAuthentic,

  /// Es la misma bóveda pero con otro salt: la contraseña maestra se
  /// cambió en otro dispositivo (ADR 0018). Se resuelve con
  /// `AdoptRemoteMasterPasswordUseCase`, pidiendo la contraseña nueva.
  passwordChanged,

  /// Es una versión igual o más vieja que la última que este dispositivo
  /// sincronizó (ADR 0019): una copia antigua restaurada o una
  /// manipulación. Se resuelve con "Subir la versión de este dispositivo".
  rollback,
}

/// El archivo de la nube no pasó la validación y **no se escribió nada**
/// localmente (ver `SyncVaultUseCase._verifyRemote`).
class RemoteVaultRejectedException implements Exception {
  final RemoteVaultRejection reason;

  const RemoteVaultRejectedException(this.reason);

  @override
  String toString() => switch (reason) {
    RemoteVaultRejection.differentVault =>
      'La nube tiene otra bóveda distinta a la tuya. No se cambió nada en '
          'este dispositivo.',
    RemoteVaultRejection.notAuthentic =>
      'La bóveda de la nube no se pudo verificar (está dañada, fue '
          'modificada o usa otra contraseña). No se cambió nada en este '
          'dispositivo.',
    RemoteVaultRejection.passwordChanged =>
      'La contraseña maestra se cambió en otro dispositivo. Ingresá la '
          'contraseña nueva para seguir sincronizando.',
    RemoteVaultRejection.rollback =>
      'La nube tiene una versión más vieja que la que este dispositivo ya '
          'sincronizó: puede ser una copia antigua restaurada o una '
          'manipulación. No se cambió nada en este dispositivo.',
  };
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
      await rejectRollback(remoteFile, ancestorStorage);
      await _verifyRemote(remoteFile);
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
      await rejectRollback(remoteFile, ancestorStorage);
      await _verifyRemote(remoteFile);
      await localStorage.write(remoteFile);
      await _markSynced(remoteFile);
      return const SyncDownloaded();
    }

    // Cambiaron los dos: merge de 3 vías (ADR 0006) + merge por campo para
    // cualquier choque real (ADR 0009) — siempre termina resuelto, nunca
    // hace falta un segundo paso.
    await rejectRollback(remoteFile, ancestorStorage);
    final ancestorFile = await ancestorStorage.exists()
        ? await ancestorStorage.read()
        : null;
    final localVault = await _decrypt(local);
    final remoteVault = await _verifyRemote(remoteFile);
    final ancestorVault = ancestorFile != null
        ? await _decrypt(ancestorFile)
        : null;

    final analysis = mergeVaults(
      ancestor: ancestorVault,
      local: localVault,
      remote: remoteVault,
    );

    await _saveAndUpload(
      analysis.autoMerged,
      revision: _nextRevision(local, remoteFile),
    );
    return SyncMerged(
      autoResolvedCount: analysis.autoResolvedCount,
      fieldConflictsResolved: analysis.fieldConflictsResolved,
    );
  }

  /// Recuperación de un [RemoteVaultRejection.rollback] (ADR 0019): el
  /// usuario confirma que la nube quedó vieja y la reemplaza con la bóveda
  /// de este dispositivo, la más nueva que conoce. No descarga nada.
  Future<SyncResult> replaceRemoteWithLocal() async {
    final local = await localStorage.read();
    await remote.uploadVault(local);
    await _markSynced(local);
    return const SyncUploaded();
  }

  /// El merge supera a los dos lados (ADR 0019).
  int _nextRevision(VaultFile local, VaultFile remote) =>
      (local.header.revision > remote.header.revision
          ? local.header.revision
          : remote.header.revision) +
      1;

  Future<VaultFile> _saveAndUpload(Vault vault, {required int revision}) async {
    final written = await SaveVaultUseCase(
      storage: localStorage,
      crypto: crypto,
    ).saveInitial(vault: vault, key: key, header: header, revision: revision);
    await remote.uploadVault(written);
    await _markSynced(written);
    return written;
  }

  Future<void> _markSynced(VaultFile file) async {
    await syncState.saveLastSyncedHash(VaultFileCodec.sha256Hex(file));
    await ancestorStorage.write(file);
  }

  /// Valida un archivo que viene de la nube **antes** de escribir nada con
  /// él: tiene que descifrarse con la clave de esta sesión (el AEAD
  /// autentica header y contenido) y ser la misma bóveda (`vault_id`).
  ///
  /// Sin esto, quien tuviera acceso a la nube del usuario (adversarios 1 y
  /// 3 del threat model) podía subir un archivo cualquiera y la siguiente
  /// sync lo copiaba sobre la bóveda local y el ancestro: pérdida de datos
  /// (revisión 2026-09-25, hallazgo S1). Si falla, lanza
  /// [RemoteVaultRejectedException] y no se toca nada local.
  Future<Vault> _verifyRemote(VaultFile file) async {
    if (file.header.vaultId != header.vaultId) {
      throw const RemoteVaultRejectedException(
        RemoteVaultRejection.differentVault,
      );
    }
    if (!sameKeyDerivation(file.header, header)) {
      throw const RemoteVaultRejectedException(
        RemoteVaultRejection.passwordChanged,
      );
    }
    try {
      return await _decrypt(file);
    } catch (_) {
      throw const RemoteVaultRejectedException(
        RemoteVaultRejection.notAuthentic,
      );
    }
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

/// Si [a] y [b] derivan la misma clave con la misma contraseña: mismo salt
/// y mismos parámetros de Argon2id. Solo cambian al cambiar la contraseña
/// maestra (ADR 0018).
bool sameKeyDerivation(VaultHeader a, VaultHeader b) {
  if (a.kdfParams.memoryKib != b.kdfParams.memoryKib ||
      a.kdfParams.iterations != b.kdfParams.iterations ||
      a.kdfParams.parallelism != b.kdfParams.parallelism ||
      a.salt.length != b.salt.length) {
    return false;
  }
  for (var i = 0; i < a.salt.length; i++) {
    if (a.salt[i] != b.salt[i]) return false;
  }
  return true;
}

/// Rechaza [remoteFile] si no supera la revisión del ancestro, el último
/// archivo que este dispositivo sincronizó (ADR 0019). Sin ancestro, o con
/// un ancestro v1 (revisión 0), no hay contra qué comparar y se confía.
/// Solo se llama cuando el remoto cambió respecto del ancestro: un cambio
/// legítimo siempre sube la revisión, así que la igualdad también se
/// rechaza.
Future<void> rejectRollback(
  VaultFile remoteFile,
  VaultStoragePort ancestorStorage,
) async {
  if (!await ancestorStorage.exists()) return;
  final baseline = (await ancestorStorage.read()).header.revision;
  if (baseline > 0 && remoteFile.header.revision <= baseline) {
    throw const RemoteVaultRejectedException(RemoteVaultRejection.rollback);
  }
}
