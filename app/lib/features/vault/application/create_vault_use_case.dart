// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Lockspire

import 'dart:typed_data';

import 'package:uuid/uuid.dart';

import '../domain/entities/vault.dart';
import '../domain/ports/crypto_port.dart';
import '../domain/ports/vault_storage_port.dart';
import '../domain/vault_file_codec.dart';
import 'save_vault_use_case.dart';
import 'unlocked_vault_result.dart';

/// Parámetros de Argon2id por defecto para bóvedas nuevas.
///
/// Memoria e iteraciones: mínimos de docs/adr/0002-motor-criptografico.md,
/// subidos (256→512 MiB) para compensar la limitación descrita en
/// docs/adr/0007-paralelismo-argon2id-libsodium.md. Deben validarse con
/// benchmarking real en el dispositivo de pruebas antes de v1 final; nunca
/// bajarlos por rendimiento.
///
/// `parallelism: 1` es literal, no aspiracional — es el único valor que la
/// API pública de libsodium usa realmente (ver ADR 0007). Debe coincidir
/// siempre con lo que el adaptador de `CryptoPort` deriva de verdad, porque
/// este valor viaja dentro del header persistido (AAD) y cualquier lector
/// futuro lo necesita para re-derivar la misma clave.
const defaultArgon2Params = Argon2Params(
  memoryKib: 524288, // 512 MiB
  iterations: 4,
  parallelism: 1,
);

const _currentFormatVersion = 1;

/// Crea una bóveda nueva y vacía, protegida con [masterPassword].
///
/// Depende solo de los puertos del dominio — testeable con fakes, sin
/// necesitar cripto real ni acceso a disco (ver ADR 0003).
class CreateVaultUseCase {
  final VaultStoragePort storage;
  final CryptoPort crypto;
  final Uuid uuid;

  const CreateVaultUseCase({
    required this.storage,
    required this.crypto,
    this.uuid = const Uuid(),
  });

  Future<UnlockedVaultResult> call({required String masterPassword}) async {
    final salt = crypto.generateSalt();
    final key = await crypto.deriveKey(
      masterPassword: masterPassword,
      salt: salt,
      params: defaultArgon2Params,
    );

    final vault = Vault(vaultId: uuid.v4(), schemaVersion: 1);

    // El nonce se conoce recién al cifrar; se excluye del AAD (ver
    // VaultHeader.toAadBytes), así que este valor provisional no importa.
    final header = VaultHeader(
      formatVersion: _currentFormatVersion,
      formatMinReaderVersion: _currentFormatVersion,
      salt: salt,
      nonce: Uint8List(0),
      vaultId: vault.vaultId,
      createdAt: DateTime.now().toUtc(),
      kdfParams: defaultArgon2Params,
    );

    // Primera escritura: no hay nada previo en disco con qué comparar, así
    // que se usa saveInitial() en vez de call() (ver SaveVaultUseCase).
    final written = await SaveVaultUseCase(
      storage: storage,
      crypto: crypto,
    ).saveInitial(vault: vault, key: key, header: header);

    return UnlockedVaultResult(
      vault: vault,
      key: key,
      header: written.header,
      fileHash: VaultFileCodec.sha256Hex(written),
    );
  }
}
