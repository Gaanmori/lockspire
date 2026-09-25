// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Lockspire

import 'package:dynamic_color/dynamic_color.dart';

import '../domain/ports/system_accent_color_port.dart';

/// [SystemAccentColorPort] con `dynamic_color` (equipo de Material):
/// en Android 12+ toma el tono principal de la paleta de Material You; en
/// escritorio, el color de acento del sistema.
class DynamicColorAccentAdapter implements SystemAccentColorPort {
  const DynamicColorAccentAdapter();

  @override
  Future<int?> accentColorArgb() async {
    try {
      final palette = await DynamicColorPlugin.getCorePalette();
      // Tono 40 de la paleta primaria: el "color de marca" que Material You
      // usa como semilla.
      if (palette != null) return palette.primary.get(40);
      final accent = await DynamicColorPlugin.getAccentColor();
      return accent?.toARGB32();
    } catch (_) {
      // Plataforma sin soporte o plugin no disponible (tests).
      return null;
    }
  }
}
