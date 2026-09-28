// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Lockspire

import 'dart:typed_data';

import 'package:lockspire/features/sync/domain/ports/active_sync_provider_port.dart';
import 'package:lockspire/features/sync/domain/ports/sync_port.dart';
import 'package:lockspire/features/sync/domain/ports/sync_state_port.dart';
import 'package:lockspire/features/sync/domain/vault_merge.dart';
import 'package:lockspire/features/vault/application/save_vault_use_case.dart';
import 'package:lockspire/features/vault/domain/entities/vault.dart';
import 'package:lockspire/features/vault/domain/ports/crypto_port.dart';
import 'package:lockspire/features/vault/domain/ports/vault_storage_port.dart';
import 'package:lockspire/features/vault/domain/vault_file_codec.dart';

import 'sync_vault_use_case.dart';

/// Muda la bóveda a otra nube, o fija su nube por primera vez (ADR 0023).
///
/// 1. Sincroniza con la nube actual ([from]) para tener lo último.
/// 2. Marca la nube nueva en la bóveda y la guarda.
/// 3. Sube esa versión a [from]: es el aviso de mudanza para los demás.
/// 4. En [to] fusiona con lo que haya (sin ancestro, unión conservadora),
///    o sube si no hay nada. Si [to] tiene **otra** bóveda, no toca nada.
///
/// Sin [from] (primera nube, o bóveda anterior a ADR 0023) omite 1 y 3.
class MoveVaultToProviderUseCase {
  final VaultStoragePort localStorage;
  final VaultStoragePort ancestorStorage;
  final SyncStatePort syncState;
  final CryptoPort crypto;
  final Uint8List key;
  final VaultHeader header;
  final SyncPort? from;
  final SyncProviderId? fromId;
  final SyncPort to;
  final SyncProviderId toId;

  const MoveVaultToProviderUseCase({
    required this.localStorage,
    required this.ancestorStorage,
    required this.syncState,
    required this.crypto,
    required this.key,
    required this.header,
    required this.from,
    required this.fromId,
    required this.to,
    required this.toId,
  });

  Future<void> call() async {
    final from = this.from;
    if (from != null) {
      await SyncVaultUseCase(
        localStorage: localStorage,
        ancestorStorage: ancestorStorage,
        remote: from,
        syncState: syncState,
        crypto: crypto,
        key: key,
        header: header,
        activeProvider: fromId,
      ).call();
    }

    // Se valida la nube nueva antes de tocar nada: si tiene otra bóveda o
    // no se puede leer, la mudanza se cancela sin dejar aviso en la vieja.
    VaultFile? remoteFile;
    Vault? remoteVault;
    if (await to.remoteVaultExists()) {
      remoteFile = await to.downloadVault();
      remoteVault = await _verifiedRemote(remoteFile);
    }

    final save = SaveVaultUseCase(storage: localStorage, crypto: crypto);
    var local = await localStorage.read();
    var vault = await _decrypt(local);
    if (syncHomeOf(vault) != toId) {
      vault = vault.copyWith(syncHome: toId.name);
      local = await save.call(
        vault: vault,
        key: key,
        header: header,
        expectedFileHash: VaultFileCodec.sha256Hex(local),
      );
    }

    if (from != null) await from.uploadVault(local);

    if (remoteFile == null || remoteVault == null) {
      await to.uploadVault(local);
      await _markSynced(local);
      return;
    }

    final merged = mergeVaults(
      ancestor: null,
      local: vault,
      remote: remoteVault,
    ).autoMerged.copyWith(syncHome: toId.name);
    final revision =
        (local.header.revision > remoteFile.header.revision
            ? local.header.revision
            : remoteFile.header.revision) +
        1;
    final written = await save.saveInitial(
      vault: merged,
      key: key,
      header: header,
      revision: revision,
    );
    await to.uploadVault(written);
    await _markSynced(written);
  }

  Future<Vault> _verifiedRemote(VaultFile remoteFile) async {
    if (remoteFile.header.vaultId != header.vaultId) {
      throw const RemoteVaultRejectedException(
        RemoteVaultRejection.differentVault,
      );
    }
    if (!sameKeyDerivation(remoteFile.header, header)) {
      throw const RemoteVaultRejectedException(
        RemoteVaultRejection.passwordChanged,
      );
    }
    try {
      return await _decrypt(remoteFile);
    } catch (_) {
      throw const RemoteVaultRejectedException(
        RemoteVaultRejection.notAuthentic,
      );
    }
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
