// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Lockspire

import 'package:flutter/material.dart';

/// Tokens de color del sistema de diseño (ver docs/design/README.md).
///
/// Ya no son constantes globales: cada tema (familia × claro/oscuro) es una
/// instancia, y las pantallas leen la del tema activo con
/// `context.palette` — así cambiar de tema no toca ninguna pantalla.
@immutable
class LockspirePalette extends ThemeExtension<LockspirePalette> {
  final Brightness brightness;

  final Color bgPage;
  final Color bgSurface;
  final Color bgSurfaceSubtle;
  final Color bgInput;

  final Color textPrimary;
  final Color textSecondary;
  final Color textPlaceholder;

  final Color accentDefault;
  final Color accentHover;
  final Color accentSecondary;

  /// Texto e iconos sobre [accentDefault] (botones rellenos). Blanco en
  /// los temas claros; el fondo de página en los oscuros, cuyo acento es
  /// más luminoso.
  final Color onAccent;

  final Color danger;

  const LockspirePalette({
    required this.brightness,
    required this.bgPage,
    required this.bgSurface,
    required this.bgSurfaceSubtle,
    required this.bgInput,
    required this.textPrimary,
    required this.textSecondary,
    required this.textPlaceholder,
    required this.accentDefault,
    required this.accentHover,
    required this.accentSecondary,
    required this.onAccent,
    required this.danger,
  });

  bool get isDark => brightness == Brightness.dark;

  @override
  LockspirePalette copyWith() => this;

  /// Sin interpolación entre temas: un cambio de tema es instantáneo, y
  /// mezclar dos paletas a mitad de animación daría colores que no existen
  /// en ninguna.
  @override
  LockspirePalette lerp(covariant LockspirePalette? other, double t) =>
      t < 0.5 ? this : (other ?? this);
}

extension LockspirePaletteContext on BuildContext {
  /// Paleta del tema activo (ver `LockspireTheme.build`).
  LockspirePalette get palette =>
      Theme.of(this).extension<LockspirePalette>() ?? LockspirePalettes.calido;
}

/// Las 6 paletas: 3 familias, cada una en claro y oscuro.
abstract final class LockspirePalettes {
  // --- Cálido (dirección original del sistema de diseño) ----------------

  static const calido = LockspirePalette(
    brightness: Brightness.light,
    bgPage: Color(0xFFFFF8F1),
    bgSurface: Color(0xFFFFFFFF),
    bgSurfaceSubtle: Color(0xFFFDEDE6),
    bgInput: Color(0xFFF6ECE1),
    textPrimary: Color(0xFF3A2E2A),
    textSecondary: Color(0xFF8A7A73),
    textPlaceholder: Color(0xFFC9B8AF),
    accentDefault: Color(0xFFEA6C4D),
    accentHover: Color(0xFFD65A3C),
    accentSecondary: Color(0xFF4FA391),
    onAccent: Color(0xFFFFFFFF),
    danger: Color(0xFFC23B3B),
  );

  static const calidoOscuro = LockspirePalette(
    brightness: Brightness.dark,
    bgPage: Color(0xFF1E1714),
    bgSurface: Color(0xFF2A211D),
    bgSurfaceSubtle: Color(0xFF3A2C26),
    bgInput: Color(0xFF332823),
    textPrimary: Color(0xFFF5E9E2),
    textSecondary: Color(0xFFBBA89E),
    textPlaceholder: Color(0xFF7D6A61),
    accentDefault: Color(0xFFF07A5A),
    accentHover: Color(0xFFE0664A),
    accentSecondary: Color(0xFF5FBFA8),
    onAccent: Color(0xFF1E1714),
    danger: Color(0xFFE5605F),
  );

  // --- Menta -------------------------------------------------------------

  static const menta = LockspirePalette(
    brightness: Brightness.light,
    bgPage: Color(0xFFF3FAF7),
    bgSurface: Color(0xFFFFFFFF),
    bgSurfaceSubtle: Color(0xFFDDF2EA),
    bgInput: Color(0xFFE7F3EE),
    textPrimary: Color(0xFF1F3A33),
    textSecondary: Color(0xFF5F7A72),
    textPlaceholder: Color(0xFF9FB8B0),
    // Más oscuro que el verde de la vista previa: con blanco encima
    // alcanza contraste AA en los botones.
    accentDefault: Color(0xFF178A6B),
    accentHover: Color(0xFF12735A),
    accentSecondary: Color(0xFF3D7BD9),
    onAccent: Color(0xFFFFFFFF),
    danger: Color(0xFFC23B3B),
  );

  static const mentaOscuro = LockspirePalette(
    brightness: Brightness.dark,
    bgPage: Color(0xFF0F1C18),
    bgSurface: Color(0xFF172822),
    bgSurfaceSubtle: Color(0xFF1F3A31),
    bgInput: Color(0xFF1A2F28),
    textPrimary: Color(0xFFE3F2EC),
    textSecondary: Color(0xFF92B3A8),
    textPlaceholder: Color(0xFF557368),
    accentDefault: Color(0xFF3CC49B),
    accentHover: Color(0xFF2FAE87),
    accentSecondary: Color(0xFF6FA3F0),
    onAccent: Color(0xFF0F1C18),
    danger: Color(0xFFE5605F),
  );

  // --- Lavanda -----------------------------------------------------------

  static const lavanda = LockspirePalette(
    brightness: Brightness.light,
    bgPage: Color(0xFFF7F5FD),
    bgSurface: Color(0xFFFFFFFF),
    bgSurfaceSubtle: Color(0xFFECE8FB),
    bgInput: Color(0xFFEEEBF7),
    textPrimary: Color(0xFF2E2A45),
    textSecondary: Color(0xFF7A7496),
    textPlaceholder: Color(0xFFB3AECB),
    accentDefault: Color(0xFF6C5CE0),
    accentHover: Color(0xFF5A4ACB),
    accentSecondary: Color(0xFF3FA28C),
    onAccent: Color(0xFFFFFFFF),
    danger: Color(0xFFC23B3B),
  );

  static const lavandaOscuro = LockspirePalette(
    brightness: Brightness.dark,
    bgPage: Color(0xFF16142A),
    bgSurface: Color(0xFF201D38),
    bgSurfaceSubtle: Color(0xFF2C2850),
    bgInput: Color(0xFF252144),
    textPrimary: Color(0xFFECE9FA),
    textSecondary: Color(0xFFA6A1C4),
    textPlaceholder: Color(0xFF625D84),
    accentDefault: Color(0xFF8F82F2),
    accentHover: Color(0xFF7B6DE6),
    accentSecondary: Color(0xFF5CC2A8),
    onAccent: Color(0xFF16142A),
    danger: Color(0xFFE5605F),
  );
}
