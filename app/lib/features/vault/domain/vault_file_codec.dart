// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Lockspire

import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

import 'ports/vault_storage_port.dart';

/// Excepción lanzada cuando un [VaultFile] no puede leerse con la versión
/// de formato soportada por esta app — rechazo explícito, nunca
/// degradación silenciosa (ver docs/adr/0004-formato-boveda-v1.md).
class UnsupportedVaultFormatException implements Exception {
  final int fileFormatMinReaderVersion;
  final int supportedFormatVersion;

  UnsupportedVaultFormatException({
    required this.fileFormatMinReaderVersion,
    required this.supportedFormatVersion,
  });

  @override
  String toString() =>
      'La bóveda requiere un lector de versión >= '
      '$fileFormatMinReaderVersion, pero esta app solo soporta '
      'la versión $supportedFormatVersion. Actualiza la app.';
}

const _currentSupportedFormatVersion = 1;
final _magic = Uint8List.fromList(utf8.encode('LKSP'));

/// Codifica/decodifica el framing binario de un [VaultFile] (ver
/// docs/adr/0004-formato-boveda-v1.md):
/// `magic(4) | formatVersion(u16) | headerLen(u32) | header(JSON, headerLen bytes) | payload cifrado`.
///
/// Compartido entre cualquier adaptador que necesite mover los bytes de la
/// bóveda (almacenamiento local, sync remoto) — la serialización es la
/// misma sin importar dónde terminen esos bytes.
abstract final class VaultFileCodec {
  static Uint8List encode(VaultFile file) {
    final headerBytes = Uint8List.fromList(
      utf8.encode(jsonEncode(file.header.toJson())),
    );

    final builder = BytesBuilder();
    builder.add(_magic);
    builder.add(_uint16BigEndian(file.header.formatVersion));
    builder.add(_uint32BigEndian(headerBytes.length));
    builder.add(headerBytes);
    builder.add(file.encryptedPayload);
    return builder.toBytes();
  }

  /// Hash del [VaultFile] completo (header + payload cifrado) tal como se
  /// vería en disco. Sirve como marcador liviano de "qué versión es esta"
  /// — lo usan tanto `SyncVaultUseCase` (detectar cambios desde la última
  /// sync) como `SaveVaultUseCase` (detectar si el archivo cambió desde
  /// que la sesión lo leyó, ver docs/STATE.md).
  static String sha256Hex(VaultFile file) =>
      sha256.convert(encode(file)).toString();

  static VaultFile decode(Uint8List bytes) {
    final data = ByteData.sublistView(bytes);

    final magic = bytes.sublist(0, 4);
    if (!_bytesEqual(magic, _magic)) {
      throw FormatException('No es un archivo de bóveda de Lockspire válido');
    }

    final formatVersion = data.getUint16(4, Endian.big);
    final headerLen = data.getUint32(6, Endian.big);
    final headerStart = 10;
    final headerBytes = bytes.sublist(headerStart, headerStart + headerLen);
    final headerJson =
        jsonDecode(utf8.decode(headerBytes)) as Map<String, dynamic>;
    final header = VaultHeader.fromJson(headerJson);

    if (header.formatMinReaderVersion > _currentSupportedFormatVersion) {
      throw UnsupportedVaultFormatException(
        fileFormatMinReaderVersion: header.formatMinReaderVersion,
        supportedFormatVersion: _currentSupportedFormatVersion,
      );
    }

    final encryptedPayload = bytes.sublist(headerStart + headerLen);

    return VaultFile(
      header: VaultHeader(
        formatVersion: formatVersion,
        formatMinReaderVersion: header.formatMinReaderVersion,
        salt: header.salt,
        nonce: header.nonce,
        vaultId: header.vaultId,
        createdAt: header.createdAt,
        kdfParams: header.kdfParams,
      ),
      encryptedPayload: encryptedPayload,
    );
  }

  static Uint8List _uint16BigEndian(int value) {
    final b = ByteData(2)..setUint16(0, value, Endian.big);
    return b.buffer.asUint8List();
  }

  static Uint8List _uint32BigEndian(int value) {
    final b = ByteData(4)..setUint32(0, value, Endian.big);
    return b.buffer.asUint8List();
  }

  static bool _bytesEqual(Uint8List a, Uint8List b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
