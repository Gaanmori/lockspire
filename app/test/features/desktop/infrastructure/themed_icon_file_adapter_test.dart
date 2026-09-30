// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Gabriel Ángel Montoya Rico

import 'dart:io';

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lockspire/design/lockspire_icon.dart';
import 'package:lockspire/features/desktop/infrastructure/themed_icon_file_adapter.dart';
import 'package:path/path.dart' as p;

import '../../../support/fake_method_channel.dart';

const _mint = LockspireIconColors(
  background: Color(0xFF87B158),
  glyph: Color(0xFFFFFFFF),
  keyhole: Color(0xFF3C5A1E),
);

/// El ícono de la ventana y la bandeja con los colores del tema: un
/// archivo por combinación de colores en la carpeta de datos de la app.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory support;

  setUp(() {
    support = Directory.systemTemp.createTempSync('lockspire_icons_');
    addTearDown(() => support.deleteSync(recursive: true));
    FakeMethodChannel(
      'plugins.flutter.io/path_provider',
    ).answer('getApplicationSupportDirectory', support.path);
  });

  test('escribe el ícono del tema: .ico en Windows, .png en Linux', () async {
    final path = await const ThemedIconFileAdapter().write(_mint);

    expect(p.isWithin(p.join(support.path, 'icons'), path), isTrue);
    final bytes = File(path).readAsBytesSync();
    if (Platform.isWindows) {
      expect(path, endsWith('.ico'));
      expect(bytes.take(4), [0, 0, 1, 0], reason: 'cabecera ICO');
    } else {
      expect(path, endsWith('.png'));
      expect(bytes.take(4), [0x89, 0x50, 0x4E, 0x47], reason: 'cabecera PNG');
    }
  });

  test('volver a un tema ya usado no lo regenera', () async {
    const adapter = ThemedIconFileAdapter();
    final first = await adapter.write(_mint);
    final written = File(first).lastModifiedSync();

    final again = await adapter.write(_mint);
    final other = await adapter.write(LockspireIconColors.lineage);

    expect(again, first);
    expect(File(again).lastModifiedSync(), written);
    expect(other, isNot(first));
  });
}
