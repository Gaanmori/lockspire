// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Lockspire

import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'lockspire_colors.dart';

/// Colores del ícono "Candado aguja": fondo, candado y cerradura.
@immutable
class LockspireIconColors {
  final Color background;
  final Color glyph;
  final Color keyhole;

  const LockspireIconColors({
    required this.background,
    required this.glyph,
    required this.keyhole,
  });

  /// El ícono de un tema sale de su versión **clara**: el mismo ícono en
  /// claro y en oscuro, como la marca de cada sistema (fondo = acento,
  /// candado = fondo de página, cerradura = acento oscuro). Con Lineage da
  /// exactamente el ícono original (#167C80 / #F6FAFA / #324B4C).
  factory LockspireIconColors.fromPalette(LockspirePalette light) =>
      LockspireIconColors(
        background: light.accentDefault,
        glyph: light.bgPage,
        keyhole: light.accentHover,
      );

  static const lineage = LockspireIconColors(
    background: Color(0xFF167C80),
    glyph: Color(0xFFF6FAFA),
    keyhole: Color(0xFF324B4C),
  );

  @override
  bool operator ==(Object other) =>
      other is LockspireIconColors &&
      other.background == background &&
      other.glyph == glyph &&
      other.keyhole == keyhole;

  @override
  int get hashCode => Object.hash(background, glyph, keyhole);
}

/// Dibuja el ícono en un lienzo de [size]. Misma geometría que
/// `docs/design/brand/lockspire-icon.svg` y `tools/generate_icons.py`
/// (lienzo base de 180×180): si se cambia uno, cambiar los otros.
class LockspireIconPainter extends CustomPainter {
  final LockspireIconColors colors;

  const LockspireIconPainter(this.colors);

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide / 180;
    canvas.scale(s);

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(0, 0, 180, 180),
        const Radius.circular(40),
      ),
      Paint()..color = colors.background,
    );

    final shackle = Path()
      ..moveTo(58, 100)
      ..lineTo(58, 76)
      ..quadraticBezierTo(58, 52, 90, 30)
      ..quadraticBezierTo(122, 52, 122, 76)
      ..lineTo(122, 100);
    canvas.drawPath(
      shackle,
      Paint()
        ..color = colors.glyph
        ..style = PaintingStyle.stroke
        ..strokeWidth = 15
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(40, 90, 100, 68),
        const Radius.circular(16),
      ),
      Paint()..color = colors.glyph,
    );

    final keyhole = Paint()..color = colors.keyhole;
    canvas.drawCircle(const Offset(90, 116), 10, keyhole);
    canvas.drawPath(
      Path()
        ..moveTo(84, 120)
        ..lineTo(96, 120)
        ..lineTo(99, 140)
        ..lineTo(81, 140)
        ..close(),
      keyhole,
    );
  }

  @override
  bool shouldRepaint(LockspireIconPainter old) => old.colors != colors;
}

/// Colores del ícono del tema elegido, para toda la app. Los calcula quien
/// arma la app (a partir del tema claro de la familia elegida) y los pone
/// por encima de `MaterialApp`; sin él, el ícono de Lineage.
class LockspireBrand extends InheritedWidget {
  final LockspireIconColors colors;

  const LockspireBrand({super.key, required this.colors, required super.child});

  static LockspireIconColors of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<LockspireBrand>()?.colors ??
      LockspireIconColors.lineage;

  @override
  bool updateShouldNotify(LockspireBrand old) => old.colors != colors;
}

/// El ícono de Lockspire como widget, con los colores del tema activo.
class LockspireIcon extends StatelessWidget {
  final double size;

  const LockspireIcon({super.key, this.size = 56});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Lockspire',
      image: true,
      child: CustomPaint(
        size: Size.square(size),
        painter: LockspireIconPainter(LockspireBrand.of(context)),
      ),
    );
  }
}

/// PNG del ícono de [pixels]×[pixels], para la ventana, la bandeja y el
/// archivo `.ico` de escritorio.
Future<Uint8List> renderLockspireIconPng(
  LockspireIconColors colors,
  int pixels,
) async {
  final recorder = ui.PictureRecorder();
  LockspireIconPainter(
    colors,
  ).paint(Canvas(recorder), Size.square(pixels.toDouble()));
  final image = await recorder.endRecording().toImage(pixels, pixels);
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  return data!.buffer.asUint8List();
}

/// Archivo `.ico` con un PNG por tamaño (formato admitido desde Windows
/// Vista). Windows necesita `.ico` para el ícono de la ventana y de la
/// bandeja.
Uint8List buildIco(Map<int, Uint8List> pngBySize) {
  final entries = pngBySize.entries.toList()
    ..sort((a, b) => a.key.compareTo(b.key));
  final header = ByteData(6 + 16 * entries.length)
    ..setUint16(0, 0, Endian.little)
    ..setUint16(2, 1, Endian.little) // tipo: ícono
    ..setUint16(4, entries.length, Endian.little);
  var offset = header.lengthInBytes;
  for (final (i, MapEntry(key: size, value: png)) in entries.indexed) {
    final at = 6 + 16 * i;
    header
      ..setUint8(at, size >= 256 ? 0 : size) // 0 = 256
      ..setUint8(at + 1, size >= 256 ? 0 : size)
      ..setUint8(at + 2, 0) // sin paleta
      ..setUint8(at + 3, 0)
      ..setUint16(at + 4, 1, Endian.little) // planos
      ..setUint16(at + 6, 32, Endian.little) // bits por píxel
      ..setUint32(at + 8, png.length, Endian.little)
      ..setUint32(at + 12, offset, Endian.little);
    offset += png.length;
  }
  final out = BytesBuilder()..add(header.buffer.asUint8List());
  for (final entry in entries) {
    out.add(entry.value);
  }
  return out.toBytes();
}
