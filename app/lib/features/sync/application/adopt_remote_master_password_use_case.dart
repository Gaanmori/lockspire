// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Lockspire

import 'dart:typed_data';

import 'package:lockspire/features/sync/domain/ports/sync_port.dart';
import 'package:lockspire/features/sync/domain/ports/sync_state_port.dart';
import 'package:lockspire/features/sync/domain/vault_merge.dart';
import 'package:lockspire/features/vault/application/change_master_password_use_case.dart'
    show IncorrectMasterPasswordException;
import 'package:lockspire/features/vault/application/save_vault_use_case.dart';
import 'package:lockspire/features/vault/application/unlocked_vault_result.dart';
import 'package:lockspire/features/vault/domain/entities/vault.dart';
import 'package:lockspire/features/vault/domain/ports/crypto_port.dart';
import 'package:lockspire/features/vault/domain/ports/vault_storage_port.dart';
import 'package:lockspire/features/vault/domain/vault_file_codec.dart';

import 'sync_vault_use_case.dart';

/// Pasa este dispositivo a la contraseña maestra que se cambió en otro —
/// ver docs/adr/0018-cambio-de-contrasena-maestra.md, "los demás
/// dispositivos". Se usa tras un `RemoteVaultRejection.passwordChanged`.
///
/// Nada se escribe hasta verificar con AEAD que [call]`(newPassword)` abre
/// el archivo remoto. Los cambios locales hechos con la contraseña vieja
/// se conservan con un merge de 3 vías (ADR 0006/0009).
class AdoptRemoteMasterPasswordUseCase {
  final VaultStoragePort localStorage;
  final VaultStoragePort ancestorStorage;
  final SyncPort remote;
  final SyncStatePort syncState;
  final CryptoPort crypto;

  /// Clave y header de la sesión actual (contraseña vieja).
  final Uint8List currentKey;
  final VaultHeader currentHeader;

  const AdoptRemoteMasterPasswordUseCase({
    required this.localStorage,
    required this.ancestorStorage,
    required this.remote,
    required this.syncState,
    required this.crypto,
    required this.currentKey,
    required this.currentHeader,
  });

  Future<UnlockedVaultResult> call({required String newPassword}) async {
    final remoteFile = await remote.downloadVault();
    if (remoteFile.header.vaultId != currentHeader.vaultId) {
      throw const RemoteVaultRejectedException(
        RemoteVaultRejection.differentVault,
      );
    }

    // Sin esto, volver a subir un archivo con la contraseña vieja revertiría
    // el cambio (consecuencia pendiente de ADR 0018, cerrada por ADR 0019).
    await rejectRollback(remoteFile, ancestorStorage);

    final newKey = await crypto.deriveKey(
      masterPassword: newPassword,
      salt: remoteFile.header.salt,
      params: remoteFile.header.kdfParams,
    );
    final Vault remoteVault;
    try {
      remoteVault = await _decrypt(remoteFile, newKey);
    } catch (_) {
      throw const IncorrectMasterPasswordException();
    }

    final local = await localStorage.read();
    final localHash = VaultFileCodec.sha256Hex(local);
    final localChanged = await syncState.lastSyncedHash() != localHash;

    if (!localChanged) {
      await localStorage.write(remoteFile);
      await _markSynced(remoteFile);
      return UnlockedVaultResult(
        vault: remoteVault,
        key: newKey,
        header: remoteFile.header,
        fileHash: VaultFileCodec.sha256Hex(remoteFile),
      );
    }

    final localVault = await _decryptWithMatchingKey(local, newKey, remoteFile);
    final ancestorVault = await ancestorStorage.exists()
        ? await _tryDecryptAncestor(
            await ancestorStorage.read(),
            newKey,
            remoteFile,
          )
        : null;

    final merged = mergeVaults(
      ancestor: ancestorVault,
      local: localVault,
      remote: remoteVault,
    ).autoMerged;

    final written =
        await SaveVaultUseCase(
          storage: localStorage,
          crypto: crypto,
        ).encryptFile(
          vault: merged,
          key: newKey,
          header: remoteFile.header,
          revision:
              (local.header.revision > remoteFile.header.revision
                  ? local.header.revision
                  : remoteFile.header.revision) +
              1,
        );
    await remote.uploadVault(written);
    await localStorage.write(written);
    await _markSynced(written);

    return UnlockedVaultResult(
      vault: merged,
      key: newKey,
      header: written.header,
      fileHash: VaultFileCodec.sha256Hex(written),
    );
  }

  /// Local y ancestro pueden estar con la clave vieja (lo normal) o, si
  /// este mismo dispositivo ya había publicado el cambio, con la nueva.
  Future<Vault> _decryptWithMatchingKey(
    VaultFile file,
    Uint8List newKey,
    VaultFile remoteFile,
  ) => _decrypt(
    file,
    sameKeyDerivation(file.header, remoteFile.header) ? newKey : currentKey,
  );

  /// Sin ancestro legible el merge sigue siendo correcto, solo más
  /// conservador (ADR 0006): nunca se pierde una entrada.
  Future<Vault?> _tryDecryptAncestor(
    VaultFile file,
    Uint8List newKey,
    VaultFile remoteFile,
  ) async {
    try {
      return await _decryptWithMatchingKey(file, newKey, remoteFile);
    } catch (_) {
      return null;
    }
  }

  Future<void> _markSynced(VaultFile file) async {
    await syncState.saveLastSyncedHash(VaultFileCodec.sha256Hex(file));
    await ancestorStorage.write(file);
  }

  Future<Vault> _decrypt(VaultFile file, Uint8List key) async {
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
