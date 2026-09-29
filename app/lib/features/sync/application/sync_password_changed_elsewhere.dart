// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Gabriel Ángel Montoya Rico

import 'dart:typed_data';

import 'package:lockspire/features/sync/domain/ports/sync_port.dart';
import 'package:lockspire/features/sync/domain/ports/sync_state_port.dart';
import 'package:lockspire/features/vault/application/password_changed_elsewhere_port.dart';
import 'package:lockspire/features/vault/application/unlocked_vault_result.dart';
import 'package:lockspire/features/vault/domain/ports/crypto_port.dart';
import 'package:lockspire/features/vault/domain/ports/vault_storage_port.dart';
import 'package:lockspire/features/vault/domain/vault_file_codec.dart';

import 'adopt_remote_master_password_use_case.dart';
import 'sync_vault_use_case.dart';
import 'package:lockspire/shared/domain/app_problem.dart';

/// [PasswordChangedElsewherePort] sobre la sync (ADR 0024).
class SyncPasswordChangedElsewhere implements PasswordChangedElsewherePort {
  final VaultStoragePort localStorage;
  final VaultStoragePort ancestorStorage;

  /// La nube activa, pedida solo cuando hace falta: prepararla puede
  /// mostrar una ventana (Google Drive en Android), así que no se hace al
  /// abrir la pantalla de bloqueo si la consulta está desactivada.
  final Future<SyncPort?> Function() loadRemote;
  final SyncStatePort syncState;
  final CryptoPort crypto;

  /// La nube para [checkRemote], que corre con la pantalla de bloqueo a
  /// la vista: tiene que armarse **sin mostrar ninguna ventana** (Google
  /// Drive en Android usa solo la API de autorización). `null` = no se
  /// puede sin ventana, y no se consulta: el aviso llega igual por la marca
  /// que deja la sync. Por defecto, [loadRemote].
  final Future<SyncPort?> Function()? loadRemoteForCheck;

  const SyncPasswordChangedElsewhere({
    required this.localStorage,
    required this.ancestorStorage,
    required this.loadRemote,
    required this.syncState,
    required this.crypto,
    this.loadRemoteForCheck,
  });

  @override
  Future<bool> isPending() => syncState.passwordChangedElsewhere();

  /// Solo cuenta como cambio de contraseña una copia **más nueva** que la
  /// última sincronizada (ADR 0019): una copia vieja o repetida con otro
  /// salt no dispara nada. Si este dispositivo cambió la contraseña y no
  /// pudo publicarla, la nube sigue igual que en la última sync y tampoco.
  @override
  Future<bool> checkRemote() async {
    try {
      final remote = await (loadRemoteForCheck ?? loadRemote)();
      if (remote == null) return await isPending();
      if (!await localStorage.exists() || !await remote.remoteVaultExists()) {
        return await isPending();
      }
      final remoteFile = await remote.downloadVault();
      final local = await localStorage.read();
      if (remoteFile.header.vaultId != local.header.vaultId ||
          VaultFileCodec.sha256Hex(remoteFile) ==
              await syncState.lastSyncedHash()) {
        return await isPending();
      }
      await rejectRollback(remoteFile, ancestorStorage);
      if (sameKeyDerivation(remoteFile.header, local.header)) {
        return await isPending();
      }
      await syncState.setPasswordChangedElsewhere(true);
      return true;
    } catch (_) {
      return isPending();
    }
  }

  @override
  Future<UnlockedVaultResult> unlockWithNewPassword({
    required String newPassword,
    String? previousPassword,
  }) async {
    final remote = await loadRemote();
    if (remote == null) {
      throw const AppProblem(AppProblemCode.syncConnectVaultCloud);
    }
    final local = await localStorage.read();
    final previousKey = previousPassword == null
        ? null
        : await _verifiedKey(local, previousPassword);
    return AdoptRemoteMasterPasswordUseCase(
      localStorage: localStorage,
      ancestorStorage: ancestorStorage,
      remote: remote,
      syncState: syncState,
      crypto: crypto,
      currentKey: previousKey,
      currentHeader: local.header,
    ).call(newPassword: newPassword);
  }

  Future<Uint8List> _verifiedKey(VaultFile local, String password) async {
    final key = await crypto.deriveKey(
      masterPassword: password,
      salt: local.header.salt,
      params: local.header.kdfParams,
    );
    try {
      await crypto.decrypt(
        key: key,
        payload: EncryptedPayload(
          nonce: local.header.nonce,
          ciphertext: local.encryptedPayload,
        ),
        aad: local.header.toAadBytes(),
      );
    } catch (_) {
      throw const IncorrectPreviousPasswordException();
    }
    return key;
  }
}
