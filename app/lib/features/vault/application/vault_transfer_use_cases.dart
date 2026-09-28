// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Lockspire

import 'dart:typed_data';

import '../domain/entities/vault.dart';
import '../domain/entities/vault_entry.dart';
import '../domain/ports/crypto_port.dart';
import '../domain/ports/vault_storage_port.dart';
import '../domain/vault_file_codec.dart';

/// Exportar pide la contraseña maestra aunque la bóveda esté abierta
/// (ADR 0027): se deriva la clave con el header de la sesión y se compara
/// en tiempo constante con la de la sesión.
class VerifyMasterPasswordUseCase {
  final CryptoPort crypto;

  const VerifyMasterPasswordUseCase({required this.crypto});

  Future<bool> call({
    required String password,
    required VaultHeader header,
    required Uint8List sessionKey,
  }) async {
    if (password.isEmpty) return false;
    final derived = await crypto.deriveKey(
      masterPassword: password,
      salt: header.salt,
      params: header.kdfParams,
    );
    return _constantTimeEquals(derived, sessionKey);
  }

  static bool _constantTimeEquals(Uint8List a, Uint8List b) {
    if (a.length != b.length) return false;
    var diff = 0;
    for (var i = 0; i < a.length; i++) {
      diff |= a[i] ^ b[i];
    }
    return diff == 0;
  }
}

/// La contraseña no abre el respaldo.
class IncorrectBackupPasswordException implements Exception {
  const IncorrectBackupPasswordException();

  @override
  String toString() =>
      'La contraseña no abre este respaldo. Es la contraseña maestra que '
      'tenía la bóveda cuando se hizo.';
}

/// Lee un respaldo de Lockspire (ADR 0027): mismas validaciones que una
/// bóveda (formato, límites de Argon2id) y verificación AEAD antes de usar
/// nada. Devuelve sus entradas vivas.
class ReadEncryptedBackupUseCase {
  final CryptoPort crypto;

  const ReadEncryptedBackupUseCase({required this.crypto});

  Future<List<VaultEntry>> call({
    required Uint8List bytes,
    required String password,
  }) async {
    final file = VaultFileCodec.decode(bytes);
    final key = await crypto.deriveKey(
      masterPassword: password,
      salt: file.header.salt,
      params: file.header.kdfParams,
    );
    final Uint8List plaintext;
    try {
      plaintext = await crypto.decrypt(
        key: key,
        payload: EncryptedPayload(
          nonce: file.header.nonce,
          ciphertext: file.encryptedPayload,
        ),
        aad: file.header.toAadBytes(),
      );
    } catch (_) {
      throw const IncorrectBackupPasswordException();
    }
    final vault = Vault.fromJsonBytes(plaintext);
    return vault.entries.where((e) => !e.deleted).toList();
  }
}

/// El respaldo cifrado es el archivo de la bóveda tal cual está en disco.
Future<Uint8List> encryptedBackupBytes(VaultStoragePort storage) async =>
    VaultFileCodec.encode(await storage.read());
