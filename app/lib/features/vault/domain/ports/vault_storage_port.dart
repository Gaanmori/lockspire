// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Lockspire

import 'dart:convert';
import 'dart:typed_data';

import 'argon2_params.dart';

export 'argon2_params.dart';

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

  /// Contador que solo sube: cada archivo nuevo tiene una revisión mayor que
  /// la del archivo del que parte. La sync rechaza un remoto que no supere
  /// la del último archivo sincronizado (protección contra rollback, ADR
  /// 0019). Los archivos v1 no lo tienen y se leen como 0.
  final int revision;

  const VaultHeader({
    required this.formatVersion,
    required this.formatMinReaderVersion,
    required this.salt,
    required this.nonce,
    required this.vaultId,
    required this.createdAt,
    required this.kdfParams,
    this.revision = 0,
  });

  VaultHeader copyWith({
    int? formatVersion,
    int? formatMinReaderVersion,
    Uint8List? salt,
    Uint8List? nonce,
    Argon2Params? kdfParams,
    int? revision,
  }) => VaultHeader(
    formatVersion: formatVersion ?? this.formatVersion,
    formatMinReaderVersion:
        formatMinReaderVersion ?? this.formatMinReaderVersion,
    salt: salt ?? this.salt,
    nonce: nonce ?? this.nonce,
    vaultId: vaultId,
    createdAt: createdAt,
    kdfParams: kdfParams ?? this.kdfParams,
    revision: revision ?? this.revision,
  );

  Map<String, dynamic> _baseJson() => {
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
    // Solo en v2 (ADR 0019): así el AAD de los archivos v1 no cambia y
    // siguen descifrándose.
    if (formatVersion >= revisionFormatVersion) 'revision': revision,
  };

  /// Serialización determinista del header, usada como AAD del AEAD (ver
  /// docs/adr/0004-formato-boveda-v1.md): cualquier manipulación de estos
  /// campos invalida la autenticación del archivo en vez de degradarla en
  /// silencio.
  ///
  /// [nonce] se excluye deliberadamente del AAD: se conoce recién al cifrar
  /// (lo devuelve [CryptoPort.encrypt]), y alterarlo ya rompe el descifrado
  /// por sí solo — no necesita autenticarse aparte, lo que evita una
  /// dependencia circular entre "calcular el AAD" y "cifrar".
  Uint8List toAadBytes() =>
      Uint8List.fromList(utf8.encode(jsonEncode(_baseJson())));

  /// Serialización completa del header tal como se persiste en disco (a
  /// diferencia de [toAadBytes], sí incluye [nonce] — un lector necesita
  /// recuperarlo para poder desencriptar).
  Map<String, dynamic> toJson() => {
    ..._baseJson(),
    'nonce': base64Encode(nonce),
  };

  factory VaultHeader.fromJson(Map<String, dynamic> json) {
    final kdf = json['kdf_params'] as Map<String, dynamic>;
    return VaultHeader(
      formatVersion: json['format_version'] as int,
      formatMinReaderVersion: json['format_min_reader_version'] as int,
      salt: base64Decode(json['salt'] as String),
      nonce: base64Decode(json['nonce'] as String),
      vaultId: json['vault_id'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      kdfParams: Argon2Params(
        memoryKib: kdf['memory_kib'] as int,
        iterations: kdf['iterations'] as int,
        parallelism: kdf['parallelism'] as int,
      ),
      revision: (json['revision'] as int?) ?? 0,
    );
  }
}

/// Primera versión del formato con [VaultHeader.revision] (ADR 0019).
const revisionFormatVersion = 2;

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

/// Crea un [VaultStoragePort] para una ruta. Lo usan otras features que
/// necesitan guardar archivos de bóveda (p. ej. el ancestro de la sync) sin
/// conocer el adaptador concreto (revisión 2026-09-25, hallazgo A4).
typedef VaultStorageFactory = VaultStoragePort Function(String path);
