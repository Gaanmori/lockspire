// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Lockspire

import '../domain/entities/vault.dart';
import '../domain/ports/crypto_port.dart';
import '../domain/ports/vault_storage_port.dart';

/// Desbloquea la bóveda existente con la contraseña maestra del usuario.
///
/// Depende solo de los puertos del dominio — testeable con fakes, sin
/// necesitar cripto real ni acceso a disco (ver ADR 0003).
class UnlockVaultUseCase {
  final VaultStoragePort storage;
  final CryptoPort crypto;

  const UnlockVaultUseCase({required this.storage, required this.crypto});

  Future<Vault> call({required String masterPassword}) async {
    final file = await storage.read();

    final key = await crypto.deriveKey(
      masterPassword: masterPassword,
      salt: file.header.salt,
    );

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
