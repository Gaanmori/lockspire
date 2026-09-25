// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Lockspire

import 'dart:typed_data';

import '../domain/entities/vault.dart';
import '../domain/ports/crypto_port.dart';
import '../domain/ports/vault_storage_port.dart';
import '../domain/vault_file_codec.dart';

/// Lanzada cuando el archivo de bóveda en disco ya no coincide con lo que
/// la sesión tenía en memoria al momento de guardar — típicamente porque
/// otro dispositivo sincronizó una versión más nueva mientras esta sesión
/// seguía desbloqueada. Se rechaza el guardado en vez de sobrescribir a
/// ciegas (ver docs/STATE.md — Fase 5, control de concurrencia optimista;
/// el merge automático real es ADR 0006, todavía pendiente).
class VaultWriteConflictException implements Exception {
  @override
  String toString() =>
      'La bóveda cambió en disco desde la última lectura de esta sesión — '
      'no se sobrescribió. Hace falta recargar antes de guardar de nuevo.';
}

/// Re-cifra y persiste una [Vault] ya desbloqueada, reusando la clave
/// derivada (sin volver a pedir la contraseña maestra ni re-derivar vía
/// Argon2id) y los metadatos del [VaultHeader] existentes (salt, vaultId,
/// kdfParams, createdAt) — solo cambia el nonce en cada escritura.
///
/// Depende solo de los puertos del dominio — testeable con fakes (ver ADR
/// 0003), igual que `CreateVaultUseCase`/`UnlockVaultUseCase`.
class SaveVaultUseCase {
  final VaultStoragePort storage;
  final CryptoPort crypto;

  const SaveVaultUseCase({required this.storage, required this.crypto});

  /// Guarda cambios sobre una bóveda ya existente, con control de
  /// concurrencia optimista: si el archivo en disco ya no coincide con
  /// [expectedFileHash] (el hash que la sesión tenía al leer/guardar por
  /// última vez), no escribe nada y lanza [VaultWriteConflictException] en
  /// vez de sobrescribir lo que haya cambiado por fuera de esta sesión.
  ///
  /// Devuelve el [VaultFile] recién escrito (header con el nonce real, ya
  /// no el provisional que se usó para armar el AAD) — el llamador saca de
  /// ahí el header y el hash actualizados para seguir guardando sin volver
  /// a leer.
  Future<VaultFile> call({
    required Vault vault,
    required Uint8List key,
    required VaultHeader header,
    required String expectedFileHash,
  }) async {
    final current = await storage.read();
    if (VaultFileCodec.sha256Hex(current) != expectedFileHash) {
      throw VaultWriteConflictException();
    }
    return _encryptAndWrite(vault: vault, key: key, header: header);
  }

  /// Primera escritura de una bóveda recién creada — todavía no hay nada
  /// previo en disco con qué comparar, así que no aplica el chequeo de
  /// conflicto de [call]. Usado únicamente por `CreateVaultUseCase`.
  Future<VaultFile> saveInitial({
    required Vault vault,
    required Uint8List key,
    required VaultHeader header,
  }) => _encryptAndWrite(vault: vault, key: key, header: header);

  Future<VaultFile> _encryptAndWrite({
    required Vault vault,
    required Uint8List key,
    required VaultHeader header,
  }) async {
    final file = await encryptFile(vault: vault, key: key, header: header);
    await storage.write(file);
    return file;
  }

  /// Cifra [vault] con [key] y los metadatos de [header] (nonce nuevo)
  /// **sin escribir nada** — para quien necesita el archivo antes de
  /// decidir dónde persistirlo (cambio de contraseña, ADR 0018).
  Future<VaultFile> encryptFile({
    required Vault vault,
    required Uint8List key,
    required VaultHeader header,
  }) async {
    final encrypted = await crypto.encrypt(
      key: key,
      plaintext: vault.toJsonBytes(),
      aad: header.toAadBytes(),
    );

    return VaultFile(
      header: VaultHeader(
        formatVersion: header.formatVersion,
        formatMinReaderVersion: header.formatMinReaderVersion,
        salt: header.salt,
        nonce: encrypted.nonce,
        vaultId: header.vaultId,
        createdAt: header.createdAt,
        kdfParams: header.kdfParams,
      ),
      encryptedPayload: encrypted.ciphertext,
    );
  }
}
