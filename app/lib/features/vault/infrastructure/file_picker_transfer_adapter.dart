// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Gabriel Ángel Montoya Rico

import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';

import '../domain/ports/file_transfer_port.dart';

/// [FileTransferPort] con el selector de archivos del sistema
/// (`file_picker`).
///
/// En Android el sistema no conoce `.lockspire` y el filtro por extensión
/// puede dejar el archivo sin elegir: ahí se ofrece cualquier archivo y el
/// formato se valida después, al leerlo ([isAndroid]).
class FilePickerTransferAdapter implements FileTransferPort {
  final bool isAndroid;

  const FilePickerTransferAdapter({required this.isAndroid});

  @override
  Future<PickedFile?> pickFile({required List<String> extensions}) async {
    final picked = await FilePicker.pickFile(
      type: isAndroid ? FileType.any : FileType.custom,
      allowedExtensions: isAndroid ? null : extensions,
    );
    if (picked == null) return null;
    // readAsBytes() funciona igual haya un path local o no: no se crea
    // ninguna copia propia del archivo.
    return PickedFile(name: picked.name, bytes: await picked.readAsBytes());
  }

  @override
  Future<bool> saveFile({
    required String dialogTitle,
    required String fileName,
    required Uint8List bytes,
    required String mimeType,
    required String extension,
  }) async {
    final saved = await FilePicker.saveFile(
      dialogTitle: dialogTitle,
      fileName: fileName,
      bytes: bytes,
      mimeType: mimeType,
      type: isAndroid ? FileType.any : FileType.custom,
      allowedExtensions: isAndroid ? null : [extension],
    );
    return saved != null;
  }
}
