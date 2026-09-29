// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Gabriel Ángel Montoya Rico

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
  // sobre los fondos oscuros de su marca. Su paleta de marca es la paleta
  // secundaria de Material You de #167C80: "brand-light" #CCE8E9 y
  // "brand-dark" #324B4C son el contenedor secundario claro y su texto.

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
    // Secundario de Material You de #167C80 (el de la interfaz de LineageOS).
    accentSecondary: Color(0xFF4A6364),
    onAccent: Color(0xFFFFFFFF),
    danger: Color(0xFFC23B3B),
  );

  static const lineageOscuro = LockspirePalette(
    brightness: Brightness.dark,
    bgPage: Color(0xFF121212),
    bgSurface: Color(0xFF1F2526),
    // #324B4C: "brand-dark" de la wiki = contenedor secundario oscuro de
    // Material You para #167C80.
    bgSurfaceSubtle: Color(0xFF324B4C),
    bgInput: Color(0xFF212626),
    textPrimary: Color(0xFFE6ECEF),
    textSecondary: Color(0xFFA3B2B8),
    textPlaceholder: Color(0xFF6B7B7D),
    accentDefault: Color(0xFF80D4D8),
    accentHover: Color(0xFF6CC2C6),
    accentSecondary: Color(0xFFB1CCCD),
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

  // --- Ubuntu (2026-09-28) ------------------------------------------------
  //
  // Tema Yaru de Ubuntu (github.com/ubuntu/yaru, `accent-colors.scss.in`):
  // acento naranja #E95420 con texto blanco, fondo claro #FAFAFA y oscuro
  // gris neutro (~#2C2C2C). Secundario: la berenjena de la marca, #77216F.

  static const ubuntu = LockspirePalette(
    brightness: Brightness.light,
    bgPage: Color(0xFFFAFAFA),
    bgSurface: Color(0xFFFFFFFF),
    bgSurfaceSubtle: Color(0xFFFBDDD2),
    bgInput: Color(0xFFEFEFEF),
    textPrimary: Color(0xFF3D3D3D),
    textSecondary: Color(0xFF6F6F6F),
    textPlaceholder: Color(0xFF9A9A9A),
    accentDefault: Color(0xFFE95420),
    accentHover: Color(0xFFC7461A),
    accentSecondary: Color(0xFF77216F),
    onAccent: Color(0xFFFFFFFF),
    danger: Color(0xFFC7162B),
  );

  static const ubuntuOscuro = LockspirePalette(
    brightness: Brightness.dark,
    bgPage: Color(0xFF262626),
    bgSurface: Color(0xFF2C2C2C),
    bgSurfaceSubtle: Color(0xFF5A2E1E),
    bgInput: Color(0xFF333333),
    textPrimary: Color(0xFFF7F7F7),
    textSecondary: Color(0xFFB8B8B8),
    textPlaceholder: Color(0xFF7A7A7A),
    accentDefault: Color(0xFFE95420),
    accentHover: Color(0xFFF06A3B),
    accentSecondary: Color(0xFFC57BBE),
    onAccent: Color(0xFFFFFFFF),
    danger: Color(0xFFF0616F),
  );

  // --- Linux Mint (2026-09-28) --------------------------------------------
  //
  // Tema Mint-Y de la versión actual de Linux Mint con Cinnamon
  // (github.com/linuxmint/mint-themes, `Mint-Y/gtk-3.0/sass/_colors.scss`):
  // acento verde #35A854 con texto blanco; claro sobre #EBEBED (fondo
  // #F8F8F9, base #FFFFFF); oscuro sobre #222226 (fondo #2E2E33, base
  // #333339); texto al 87 % de negro/blanco. Secundario: su azul de
  // enlaces #5294E2.

  static const mint = LockspirePalette(
    brightness: Brightness.light,
    bgPage: Color(0xFFF8F8F9),
    bgSurface: Color(0xFFFFFFFF),
    bgSurfaceSubtle: Color(0xFFD5EEDC),
    bgInput: Color(0xFFEBEBED),
    textPrimary: Color(0xFF212121),
    textSecondary: Color(0xFF616161),
    textPlaceholder: Color(0xFF9E9E9E),
    accentDefault: Color(0xFF35A854),
    accentHover: Color(0xFF2C8C46),
    accentSecondary: Color(0xFF5294E2),
    onAccent: Color(0xFFFFFFFF),
    danger: Color(0xFFD93025),
  );

  static const mintOscuro = LockspirePalette(
    brightness: Brightness.dark,
    bgPage: Color(0xFF2E2E33),
    bgSurface: Color(0xFF333339),
    bgSurfaceSubtle: Color(0xFF264A31),
    bgInput: Color(0xFF3A3A40),
    textPrimary: Color(0xFFEDEDED),
    textSecondary: Color(0xFFB0B0B5),
    textPlaceholder: Color(0xFF7C7C82),
    accentDefault: Color(0xFF35A854),
    accentHover: Color(0xFF3FBF61),
    accentSecondary: Color(0xFF5294E2),
    onAccent: Color(0xFFFFFFFF),
    danger: Color(0xFFFC4138),
  );

  // --- Windows 11 (2026-09-28) --------------------------------------------
  //
  // Fluent / WinUI 3 con el acento azul por defecto de Windows 11: acento
  // #005FB8 con texto blanco en claro y #60CDFF con texto negro en oscuro
  // (AccentFillColorDefault); fondo Mica #F3F3F3 / #202020, tarjetas
  // #FFFFFF / #2B2B2B, texto #1A1A1A y secundario #5D5D5D en claro,
  // blanco y #C5C5C5 en oscuro; rojo "crítico" #C42B1C / #FF99A4.

  static const windows = LockspirePalette(
    brightness: Brightness.light,
    bgPage: Color(0xFFF3F3F3),
    bgSurface: Color(0xFFFFFFFF),
    bgSurfaceSubtle: Color(0xFFCCE4F7),
    bgInput: Color(0xFFFBFBFB),
    textPrimary: Color(0xFF1A1A1A),
    textSecondary: Color(0xFF5D5D5D),
    textPlaceholder: Color(0xFF8A8A8A),
    accentDefault: Color(0xFF005FB8),
    accentHover: Color(0xFF1A6FC0),
    accentSecondary: Color(0xFF0078D4),
    onAccent: Color(0xFFFFFFFF),
    danger: Color(0xFFC42B1C),
  );

  static const windowsOscuro = LockspirePalette(
    brightness: Brightness.dark,
    bgPage: Color(0xFF202020),
    bgSurface: Color(0xFF2B2B2B),
    bgSurfaceSubtle: Color(0xFF1F3A52),
    bgInput: Color(0xFF2D2D2D),
    textPrimary: Color(0xFFFFFFFF),
    textSecondary: Color(0xFFC5C5C5),
    textPlaceholder: Color(0xFF8B8B8B),
    accentDefault: Color(0xFF60CDFF),
    accentHover: Color(0xFF4CC2FF),
    accentSecondary: Color(0xFF99EBFF),
    onAccent: Color(0xFF000000),
    danger: Color(0xFFFF99A4),
  );
}
