// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Gabriel Ángel Montoya Rico

import 'dart:typed_data';

import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lockspire/features/appearance/infrastructure/dynamic_color_accent_adapter.dart';

import '../../../support/fake_method_channel.dart';

/// El color de acento del sistema para el tema "Sistema": Material You en
/// Android, el acento de Windows o de GTK en escritorio.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeMethodChannel plugin;
  const adapter = DynamicColorAccentAdapter();

  setUp(() => plugin = FakeMethodChannel(DynamicColorPlugin.channel.name));

  test('en Android usa el tono 40 de la paleta primaria de Material '
      'You', () async {
    // Cinco paletas de 13 tonos (0, 10, 20, 30, 40...); la primaria va
    // primero, y su tono 40 es el quinto valor. Kotlin la manda como
    // IntArray, que llega como Int32List (ARGB con signo).
    final palette = Int32List.fromList(
      List<int>.generate(5 * 13, (i) => 0x0F000000 + i),
    );
    plugin.answer('getCorePalette', palette);

    expect(await adapter.accentColorArgb(), 0x0F000004);
  });

  test('en escritorio usa el color de acento', () async {
    plugin.answer('getAccentColor', 0xFF0078D4);

    expect(await adapter.accentColorArgb(), 0xFF0078D4);
  });

  test('sin soporte, no hay color', () async {
    expect(await adapter.accentColorArgb(), isNull);

    plugin.fail('getCorePalette');
    expect(await adapter.accentColorArgb(), isNull);
  });
}
