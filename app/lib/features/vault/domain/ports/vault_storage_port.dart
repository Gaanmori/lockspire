// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Lockspire

import 'dart:convert';
import 'dart:typed_data';

/// Parámetros de Argon2id usados para derivar la clave de una bóveda.
/// Ver docs/adr/0002-motor-criptografico.md para los valores mínimos
/// recomendados (memoria ≥256 MiB, iteraciones ≥3-4).
class Argon2Params {
  final int memoryKib;
  final int iterations;
  final int parallelism;

  const Argon2Params({
    required this.memoryKib,
    required this.iterations,
    required this.parallelism,
  });
}

/// Header del archivo de bóveda: va sin cifrar pero autenticado como AAD
/// del AEAD (ver docs/adr/0004-formato-boveda-v1.md). Cualquier
/// manipulación de estos campos invalida la autenticación del archivo.
class VaultHeader {
  final int formatVersion;
  final int formatMinReaderVersion;
  final Uint8List salt;
  final Uint8List nonce;
  final String vaultId;
  final DateTime createdAt;
  final Argon2Params kdfParams;

  const VaultHeader({
    required this.formatVersion,
    required this.formatMinReaderVersion,
    required this.salt,
    required this.nonce,
    required this.vaultId,
    required this.createdAt,
    required this.kdfParams,
  });

  /// Serialización determinista del header, usada como AAD del AEAD (ver
  /// docs/adr/0004-formato-boveda-v1.md): cualquier manipulación de estos
  /// campos invalida la autenticación del archivo en vez de degradarla en
  /// silencio.
  ///
  /// [nonce] se excluye deliberadamente del AAD: se conoce recién al cifrar
  /// (lo devuelve [CryptoPort.encrypt]), y alterarlo ya rompe el descifrado
  /// por sí solo — no necesita autenticarse aparte, lo que evita una
  /// dependencia circular entre "calcular el AAD" y "cifrar".
  Uint8List toAadBytes() {
    final map = {
      'format_version': formatVersion,
      'format_min_reader_version': formatMinReaderVersion,
      'salt': base64Encode(salt),
      'vault_id': vaultId,
      'created_at': createdAt.toIso8601String(),
      'kdf_params': {
        'memory_kib': kdfParams.memoryKib,
        'iterations': kdfParams.iterations,
        'parallelism': kdfParams.parallelism,
      },
    };
    return Uint8List.fromList(utf8.encode(jsonEncode(map)));
  }
}

/// Archivo de bóveda completo tal como vive en disco: header en claro +
/// payload cifrado (blob único, ver docs/adr/0004-formato-boveda-v1.md).
class VaultFile {
  final VaultHeader header;
  final Uint8List encryptedPayload;

  const VaultFile({required this.header, required this.encryptedPayload});
}

/// Puerto de almacenamiento del archivo de bóveda.
///
/// Los adaptadores que implementen este puerto (infrastructure/) deben
/// escribir siempre de forma atómica (temporal + fsync + rename), nunca
/// sobrescritura en sitio — regla fijada en CLAUDE.md.
abstract class VaultStoragePort {
  Future<bool> exists();

  Future<VaultFile> read();

  Future<void> write(VaultFile file);
}
