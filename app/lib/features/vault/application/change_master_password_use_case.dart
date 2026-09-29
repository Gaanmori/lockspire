// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Gabriel Ángel Montoya Rico

import 'dart:typed_data';

import '../domain/entities/vault.dart';
import '../domain/ports/crypto_port.dart';
import '../domain/ports/master_password_change_replica_port.dart';
import '../domain/ports/vault_storage_port.dart';
import '../domain/vault_file_codec.dart';
import 'create_vault_use_case.dart' show defaultArgon2Params;
import 'master_password_policy.dart';
import 'save_vault_use_case.dart';
import 'incorrect_master_password_exception.dart';
import 'unlocked_vault_result.dart';

export 'incorrect_master_password_exception.dart';

/// La contraseña nueva no cumple la política (ADR 0018).
class WeakMasterPasswordException implements Exception {
  final MasterPasswordProblem problem;

  const WeakMasterPasswordException(this.problem);

  @override
  String toString() => 'WeakMasterPasswordException(${problem.name})';
}

/// Cambia la contraseña maestra: salt nuevo, clave nueva y la bóveda
/// recifrada — ver docs/adr/0018-cambio-de-contrasena-maestra.md.
///
/// Orden deliberado: verificar la contraseña actual → sincronizar con la
/// clave actual → recifrar → **publicar** → escribir local. Cualquier
/// fallo antes de publicar deja todo como estaba.
class ChangeMasterPasswordUseCase {
  final VaultStoragePort storage;
  final CryptoPort crypto;
  final MasterPasswordChangeReplicaPort replica;

  const ChangeMasterPasswordUseCase({
    required this.storage,
    required this.crypto,
    required this.replica,
  });

  Future<UnlockedVaultResult> call({
    required String currentPassword,
    required String newPassword,
  }) async {
    final problem = checkNewMasterPassword(newPassword);
    if (problem != null) throw WeakMasterPasswordException(problem);

    final before = await storage.read();
    final currentKey = await crypto.deriveKey(
      masterPassword: currentPassword,
      salt: before.header.salt,
      params: before.header.kdfParams,
    );
    try {
      await _decrypt(before, currentKey);
    } catch (_) {
      throw const IncorrectMasterPasswordException();
    }

    await replica.syncBeforeChange(key: currentKey, header: before.header);

    // La sync pudo haber bajado o fusionado cambios: se recifra lo que
    // quedó en disco, no lo que había antes. Mismo salt (la sync rechaza
    // un remoto con otro salt), así que la clave actual lo abre.
    final synced = await storage.read();
    final vault = await _decrypt(synced, currentKey);
    final syncedHash = VaultFileCodec.sha256Hex(synced);

    final newSalt = crypto.generateSalt();
    final newKey = await crypto.deriveKey(
      masterPassword: newPassword,
      salt: newSalt,
      params: defaultArgon2Params,
    );
    // Misma bóveda (vault_id, created_at, formato); salt y parámetros de
    // Argon2id nuevos — de paso se actualizan si eran de una versión vieja.
    final rekeyed = await SaveVaultUseCase(storage: storage, crypto: crypto)
        .encryptFile(
          vault: vault,
          key: newKey,
          header: VaultHeader(
            formatVersion: synced.header.formatVersion,
            formatMinReaderVersion: synced.header.formatMinReaderVersion,
            salt: newSalt,
            nonce: Uint8List(0),
            vaultId: synced.header.vaultId,
            createdAt: synced.header.createdAt,
            kdfParams: defaultArgon2Params,
            // encryptFile la sube en 1 (ADR 0019).
            revision: synced.header.revision,
          ),
        );

    await replica.publish(rekeyed);

    // Si algo escribió la bóveda local entre la sync y acá, no se pisa: la
    // próxima sync verá el salt nuevo en la nube y pedirá la contraseña
    // nueva para combinar (ADR 0018, "los demás dispositivos").
    if (VaultFileCodec.sha256Hex(await storage.read()) != syncedHash) {
      throw VaultWriteConflictException();
    }
    await storage.write(rekeyed);

    return UnlockedVaultResult(
      vault: vault,
      key: newKey,
      header: rekeyed.header,
      fileHash: VaultFileCodec.sha256Hex(rekeyed),
    );
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
