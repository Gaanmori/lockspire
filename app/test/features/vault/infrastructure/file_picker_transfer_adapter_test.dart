// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Gabriel Ángel Montoya Rico

import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lockspire/features/vault/infrastructure/file_picker_transfer_adapter.dart';

/// Un archivo elegido que solo existe en memoria (como un `content://` de
/// Android, sin ruta local).
final class _Picked extends PlatformFile {
  @override
  final String name;
  final Uint8List bytes;

  _Picked(this.name, this.bytes);

  @override
  Uri get uri => Uri.parse('content://documentos/$name');

  @override
  Future<Uint8List> readAsBytes() async => bytes;

  @override
  Stream<Uint8List> readAsByteStream() => Stream.value(bytes);

  @override
  int? lengthSync() => bytes.length;

  @override
  Future<int> length() async => bytes.length;

  @override
  Never get xFile => throw UnimplementedError();
}

/// El selector de archivos del sistema, simulado por debajo de
/// `file_picker`.
class _FakePicker extends FilePickerPlatform {
  PlatformFile? toPick;
  Uri? savedAt;
  FileType? pickedType;
  List<String>? pickedExtensions;
  ({String name, String mimeType})? saved;

  @override
  Future<PlatformFile?> pickFile({
    String? dialogTitle,
    String? initialDirectory,
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    Function(FilePickerStatus)? onFileLoading,
    int compressionQuality = 0,
    AndroidOptions androidOptions = const AndroidOptions(),
    DarwinOptions darwinOptions = const DarwinOptions(),
    WindowsOptions windowsOptions = const WindowsOptions(),
    LinuxOptions linuxOptions = const LinuxOptions(),
    WebOptions webOptions = const WebOptions(),
  }) async {
    pickedType = type;
    pickedExtensions = allowedExtensions;
    return toPick;
  }

  @override
  Future<Uri?> saveFile({
    required String fileName,
    required Uint8List bytes,
    required String mimeType,
    String? dialogTitle,
    String? initialDirectory,
    Function(FilePickerStatus)? onFileSaving,
    WindowsOptions windowsOptions = const WindowsOptions(),
    LinuxOptions linuxOptions = const LinuxOptions(),
    WebOptions webOptions = const WebOptions(),
  }) async {
    saved = (name: fileName, mimeType: mimeType);
    return savedAt;
  }
}

/// Importar y exportar pasan por el selector de archivos del sistema.
void main() {
  late _FakePicker picker;

  setUp(() => FilePickerPlatform.instance = picker = _FakePicker());

  test('en escritorio filtra por extensión y lee el archivo', () async {
    picker.toPick = _Picked('respaldo.lockspire', Uint8List.fromList([1, 2]));

    final file = await const FilePickerTransferAdapter(
      isAndroid: false,
    ).pickFile(extensions: ['lockspire']);

    expect(file!.name, 'respaldo.lockspire');
    expect(file.bytes, [1, 2]);
    expect(picker.pickedType, FileType.custom);
    expect(picker.pickedExtensions, ['lockspire']);
  });

  test('en Android ofrece cualquier archivo, porque el sistema no conoce '
      '.lockspire', () async {
    final file = await const FilePickerTransferAdapter(
      isAndroid: true,
    ).pickFile(extensions: ['lockspire']);

    expect(file, isNull, reason: 'el usuario canceló');
    expect(picker.pickedType, FileType.any);
    expect(picker.pickedExtensions, isNull);
  });

  test('guardar dice si el usuario eligió dónde', () async {
    const adapter = FilePickerTransferAdapter(isAndroid: false);
    Future<bool> save() => adapter.saveFile(
      dialogTitle: 'Exportar',
      fileName: 'lockspire.csv',
      bytes: Uint8List.fromList([7]),
      mimeType: 'text/csv',
      extension: 'csv',
    );

    expect(await save(), isFalse);

    picker.savedAt = Uri.file('/descargas/lockspire.csv');
    expect(await save(), isTrue);
    expect(picker.saved, (name: 'lockspire.csv', mimeType: 'text/csv'));
  });
}
