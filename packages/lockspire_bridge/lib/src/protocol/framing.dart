// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Gabriel Ángel Montoya Rico

import 'dart:convert';
import 'dart:typed_data';

import 'protocol_exception.dart';

/// Tamaño máximo de un mensaje (sin contar el prefijo de 4 bytes). Chrome
/// limita a 1 MB lo que un native host puede enviarle; se usa el mismo
/// límite en todos los tramos (ADR 0013).
const maxFrameBytes = 1024 * 1024;

/// Codifica [message] como un frame de Native Messaging: longitud uint32
/// little-endian + JSON UTF-8.
Uint8List encodeFrame(Map<String, Object?> message) {
  final body = utf8.encode(jsonEncode(message));
  if (body.length > maxFrameBytes) {
    throw const BridgeProtocolException('frame demasiado grande');
  }
  final frame = Uint8List(4 + body.length);
  ByteData.sublistView(frame).setUint32(0, body.length, Endian.little);
  frame.setRange(4, frame.length, body);
  return frame;
}

/// Decodifica el cuerpo de un frame (sin prefijo) a un objeto JSON.
/// Rechaza cualquier cosa que no sea un objeto en la raíz.
Map<String, Object?> decodeFrameBody(List<int> body) {
  final Object? decoded;
  try {
    decoded = jsonDecode(utf8.decode(body));
  } on FormatException {
    throw const BridgeProtocolException('JSON o UTF-8 inválido');
  }
  if (decoded is! Map<String, Object?>) {
    throw const BridgeProtocolException('el mensaje no es un objeto JSON');
  }
  return decoded;
}

/// Acumula bytes de un stream y va extrayendo frames completos. Lanza
/// [BridgeProtocolException] si un frame anuncia un tamaño mayor que
/// [maxFrameBytes] — antes de reservar memoria para él.
class FrameDecoder {
  final _buffer = BytesBuilder(copy: false);
  Uint8List _pending = Uint8List(0);

  /// Añade [chunk] y devuelve los cuerpos de los frames que quedaron
  /// completos (sin el prefijo de longitud).
  List<Uint8List> add(List<int> chunk) {
    _buffer.add(_pending);
    _buffer.add(chunk);
    var data = _buffer.takeBytes();
    final frames = <Uint8List>[];
    while (data.length >= 4) {
      final length = ByteData.sublistView(data).getUint32(0, Endian.little);
      if (length > maxFrameBytes) {
        throw const BridgeProtocolException('frame demasiado grande');
      }
      if (data.length < 4 + length) break;
      frames.add(Uint8List.fromList(data.sublist(4, 4 + length)));
      data = Uint8List.sublistView(data, 4 + length);
    }
    _pending = Uint8List.fromList(data);
    return frames;
  }

  /// `true` si hay bytes de un frame incompleto sin consumir.
  bool get hasPartialFrame => _pending.isNotEmpty;
}
