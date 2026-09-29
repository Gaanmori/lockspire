// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Gabriel Ángel Montoya Rico

import 'dart:typed_data';

/// Un archivo que eligió el usuario: su nombre (para reconocer el formato)
/// y su contenido, leído en memoria sin guardar ninguna copia
/// (docs/THREAT_MODEL.md, actor #8).
class PickedFile {
  final String name;
  final Uint8List bytes;

  const PickedFile({required this.name, required this.bytes});
}

/// Intercambio de archivos con el usuario para importar y exportar (ADR
/// 0027): elegir uno para leer, o dónde guardar uno nuevo. El selector del
/// sistema y sus diferencias por plataforma quedan en el adaptador.
abstract class FileTransferPort {
  /// Pide un archivo para importar, filtrando por [extensions] donde el
  /// sistema lo permita. `null` si el usuario canceló.
  Future<PickedFile?> pickFile({required List<String> extensions});

  /// Pide dónde guardar [bytes] como [fileName]. `false` si el usuario
  /// canceló.
  Future<bool> saveFile({
    required String dialogTitle,
    required String fileName,
    required Uint8List bytes,
    required String mimeType,
    required String extension,
  });
}
