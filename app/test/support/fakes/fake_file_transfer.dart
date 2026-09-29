// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Gabriel Ángel Montoya Rico

import 'dart:convert';
import 'dart:typed_data';

import 'package:lockspire/features/vault/domain/ports/file_transfer_port.dart';

/// Un archivo que el usuario guardó al exportar.
class SavedFile {
  final String fileName;
  final Uint8List bytes;

  const SavedFile(this.fileName, this.bytes);

  String get text => utf8.decode(bytes);
}

/// Selector de archivos en memoria: [nextPick] es lo que "elige" el usuario
/// (`null`: cancela) y [saved] lo que guardó.
class FakeFileTransfer implements FileTransferPort {
  PickedFile? nextPick;
  bool cancelSave = false;
  final saved = <SavedFile>[];

  /// Prepara la próxima elección con un archivo de texto.
  void willPickText(String name, String content) => nextPick = PickedFile(
    name: name,
    bytes: Uint8List.fromList(utf8.encode(content)),
  );

  /// Prepara la próxima elección con un archivo ya guardado.
  void willPick(SavedFile file) =>
      nextPick = PickedFile(name: file.fileName, bytes: file.bytes);

  @override
  Future<PickedFile?> pickFile({required List<String> extensions}) async =>
      nextPick;

  @override
  Future<bool> saveFile({
    required String dialogTitle,
    required String fileName,
    required Uint8List bytes,
    required String mimeType,
    required String extension,
  }) async {
    if (cancelSave) return false;
    saved.add(SavedFile(fileName, bytes));
    return true;
  }
}
