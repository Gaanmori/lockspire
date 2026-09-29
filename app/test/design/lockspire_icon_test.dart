// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Gabriel Ángel Montoya Rico

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:lockspire/design/lockspire_colors.dart';
import 'package:lockspire/design/lockspire_icon.dart';
import 'package:lockspire/design/lockspire_theme.dart';

void main() {
  test('con Lineage sale exactamente el ícono original de la marca', () {
    expect(
      LockspireIconColors.fromPalette(LockspirePalettes.lineage),
      LockspireIconColors.lineage,
    );
  });

  test('cada familia tiene su propio ícono, igual en claro y en oscuro', () {
    final byFamily = {
      for (final f in LockspireThemeFamily.values)
        f: LockspireIconColors.fromPalette(f.light),
    };
    expect(byFamily.values.toSet(), hasLength(byFamily.length));
    expect(
      LockspireIconColors.fromPalette(LockspirePalettes.ubuntu).background,
      LockspirePalettes.ubuntu.accentDefault,
    );
  });

  test('el .ico lleva un PNG por tamaño con su entrada de directorio', () {
    final png16 = Uint8List.fromList(List.filled(10, 1));
    final png256 = Uint8List.fromList(List.filled(20, 2));
    final ico = buildIco({256: png256, 16: png16});
    final data = ByteData.sublistView(ico);

    expect(data.getUint16(2, Endian.little), 1, reason: 'tipo ícono');
    expect(data.getUint16(4, Endian.little), 2, reason: 'dos imágenes');
    // Primera entrada: 16 px; segunda: 256 px se escribe como 0.
    expect(ico[6], 16);
    expect(ico[22], 0);
    final firstOffset = data.getUint32(6 + 12, Endian.little);
    expect(firstOffset, 6 + 16 * 2);
    expect(ico.sublist(firstOffset, firstOffset + 10), png16);
    expect(ico.length, 6 + 32 + 10 + 20);
  });
}
