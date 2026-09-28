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

  /// Paleta generada con el algoritmo tonal de Material 3 a partir de
  /// [seed], para el tema "Colores del sistema". Traduce los roles de
  /// `ColorScheme` a nuestros tokens: las pantallas no distinguen una
  /// paleta generada de una fija.
  factory LockspirePalette.fromSeed(Color seed, Brightness brightness) {
    final s = ColorScheme.fromSeed(seedColor: seed, brightness: brightness);
    return LockspirePalette(
      brightness: brightness,
      bgPage: s.surface,
      bgSurface: s.surfaceContainerLow,
      bgSurfaceSubtle: s.secondaryContainer,
      bgInput: s.surfaceContainerHighest,
      textPrimary: s.onSurface,
      textSecondary: s.onSurfaceVariant,
      textPlaceholder: s.outline,
      accentDefault: s.primary,
      accentHover: Color.lerp(s.primary, s.onSurface, 0.15)!,
      accentSecondary: s.tertiary,
      onAccent: s.onPrimary,
      danger: s.error,
    );
  }

  bool get isDark => brightness == Brightness.dark;

  List<Object> get _props => [
    brightness,
    bgPage,
    bgSurface,
    bgSurfaceSubtle,
    bgInput,
    textPrimary,
    textSecondary,
    textPlaceholder,
    accentDefault,
    accentHover,
    accentSecondary,
    onAccent,
    danger,
  ];

  /// Igualdad por valor: dos paletas generadas desde el mismo color son la
  /// misma paleta (la caché de `LockspireTheme.of` depende de esto).
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! LockspirePalette) return false;
    final a = _props;
    final b = other._props;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hashAll(_props);

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
      Theme.of(this).extension<LockspirePalette>() ?? LockspirePalettes.lineage;
}

/// Las 6 paletas: 3 familias, cada una en claro y oscuro.
abstract final class LockspirePalettes {
  // --- Lineage (tema principal y por defecto, 2026-09-27) ----------------
  //
  // Basado en el tema por defecto de LineageOS. Claro: su paleta de marca
  // (lineage_wiki `_sass/lineage/_theme.scss`; `lineage_accent` = #167C80 en
  // SetupWizard). Oscuro: lo que muestra Android con LineageOS, que pasa la
  // semilla #167C80 por el algoritmo tonal de Material You (primary tono 80)
  // sobre los fondos oscuros de su marca.

  static const lineage = LockspirePalette(
    brightness: Brightness.light,
    bgPage: Color(0xFFF6FAFA),
    bgSurface: Color(0xFFFFFFFF),
    bgSurfaceSubtle: Color(0xFFCCE8E9),
    bgInput: Color(0xFFE1EFEF),
    textPrimary: Color(0xFF3C4858),
    textSecondary: Color(0xFF6C757D),
    textPlaceholder: Color(0xFFA3B2B8),
    accentDefault: Color(0xFF167C80),
    accentHover: Color(0xFF324B4C),
    accentSecondary: Color(0xFF1F6B3A),
    onAccent: Color(0xFFFFFFFF),
    danger: Color(0xFFC23B3B),
  );

  static const lineageOscuro = LockspirePalette(
    brightness: Brightness.dark,
    bgPage: Color(0xFF121212),
    bgSurface: Color(0xFF1F2526),
    bgSurfaceSubtle: Color(0xFF243738),
    bgInput: Color(0xFF212626),
    textPrimary: Color(0xFFE6ECEF),
    textSecondary: Color(0xFFA3B2B8),
    textPlaceholder: Color(0xFF6B7B7D),
    accentDefault: Color(0xFF80D4D8),
    accentHover: Color(0xFF6CC2C6),
    accentSecondary: Color(0xFF8FD4A5),
    onAccent: Color(0xFF003739),
    danger: Color(0xFFE5605F),
  );

  // --- Pixel (2026-09-28) --------------------------------------------------
  //
  // El aspecto de un Google Pixel: Material You genera todos los colores
  // con el algoritmo tonal ("tonal spot") a partir de una semilla. Semilla:
  // el azul de Google #4285F4. Valores calculados con el mismo algoritmo que
  // usa "Colores del sistema" (`LockspirePalette.fromSeed`) y fijados aquí
  // para que sean una familia como las demás.

  static const pixel = LockspirePalette(
    brightness: Brightness.light,
    bgPage: Color(0xFFF9F9FF),
    bgSurface: Color(0xFFF3F3FA),
    bgSurfaceSubtle: Color(0xFFDBE2F9),
    bgInput: Color(0xFFE2E2E9),
    textPrimary: Color(0xFF1A1B20),
    textSecondary: Color(0xFF44474F),
    textPlaceholder: Color(0xFF74777F),
    accentDefault: Color(0xFF445E91),
    accentHover: Color(0xFF3E5480),
    accentSecondary: Color(0xFF715573),
    onAccent: Color(0xFFFFFFFF),
    danger: Color(0xFFBA1A1A),
  );

  static const pixelOscuro = LockspirePalette(
    brightness: Brightness.dark,
    bgPage: Color(0xFF111318),
    bgSurface: Color(0xFF1A1B20),
    bgSurfaceSubtle: Color(0xFF3F4759),
    bgInput: Color(0xFF33353A),
    textPrimary: Color(0xFFE2E2E9),
    textSecondary: Color(0xFFC4C6D0),
    textPlaceholder: Color(0xFF8E9099),
    accentDefault: Color(0xFFADC6FF),
    accentHover: Color(0xFFB5CAFC),
    accentSecondary: Color(0xFFDEBCDF),
    onAccent: Color(0xFF102F60),
    danger: Color(0xFFFFB4AB),
  );

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
