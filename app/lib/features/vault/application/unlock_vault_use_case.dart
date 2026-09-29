// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Gabriel Ángel Montoya Rico

import 'dart:typed_data';

import '../domain/entities/vault.dart';
import '../domain/ports/crypto_port.dart';
import '../domain/ports/vault_storage_port.dart';
import '../domain/vault_file_codec.dart';
import 'unlocked_vault_result.dart';

/// Desbloquea la bóveda existente con la contraseña maestra del usuario.
///
/// Depende solo de los puertos del dominio — testeable con fakes, sin
/// necesitar cripto real ni acceso a disco (ver ADR 0003).
class UnlockVaultUseCase {
  final VaultStoragePort storage;
  final CryptoPort crypto;

  const UnlockVaultUseCase({required this.storage, required this.crypto});

  Future<UnlockedVaultResult> call({required String masterPassword}) async {
    final file = await storage.read();

    final key = await crypto.deriveKey(
      masterPassword: masterPassword,
      salt: file.header.salt,
      params: file.header.kdfParams,
    );

    return _decrypt(file: file, key: key);
  }

  /// Vuelve a leer y desencriptar el archivo actual con una clave ya
  /// derivada — sin pedir la contraseña maestra ni volver a pasar por
  /// Argon2id. Usado para recuperarse de un [VaultWriteConflictException]
  /// (ver `SaveVaultUseCase`): la contraseña maestra no cambió, solo el
  /// contenido en disco (típicamente por una sync externa), así que la
  /// clave ya retenida en la sesión sigue siendo válida para descifrarlo.
  Future<UnlockedVaultResult> reloadWithKey({required Uint8List key}) async {
    final file = await storage.read();
    return _decrypt(file: file, key: key);
  }

  /// Desbloquea un [VaultFile] que no vino de [storage] — usado para
  /// restaurar una bóveda descargada de un proveedor de sync en un
  /// dispositivo sin bóveda local todavía (ver
  /// `VaultSessionController.restoreFromDownloadedFile`). Deriva la clave
  /// desde el propio header del archivo, igual que [call], solo que sin
  /// pasar por `storage.read()`.
  Future<UnlockedVaultResult> unlockFile({
    required VaultFile file,
    required String masterPassword,
  }) async {
    final key = await crypto.deriveKey(
      masterPassword: masterPassword,
      salt: file.header.salt,
      params: file.header.kdfParams,
    );
    return _decrypt(file: file, key: key);
  }

  Future<UnlockedVaultResult> _decrypt({
    required VaultFile file,
    required Uint8List key,
  }) async {
    final plaintext = await crypto.decrypt(
      key: key,
      payload: EncryptedPayload(
        nonce: file.header.nonce,
        ciphertext: file.encryptedPayload,
      ),
      aad: file.header.toAadBytes(),
    );

    return UnlockedVaultResult(
      vault: Vault.fromJsonBytes(plaintext),
      key: key,
      header: file.header,
      fileHash: VaultFileCodec.sha256Hex(file),
    );
  }
}
