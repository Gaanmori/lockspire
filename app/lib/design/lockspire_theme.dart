// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Lockspire

import 'package:flutter/material.dart';

import 'lockspire_colors.dart';
import 'lockspire_spacing.dart';

/// Familias de tema: cada una con versión clara y oscura (ver
/// docs/design/README.md).
enum LockspireThemeFamily {
  lineage(
    'Lineage',
    LockspirePalettes.lineage,
    LockspirePalettes.lineageOscuro,
  ),
  pixel('Pixel', LockspirePalettes.pixel, LockspirePalettes.pixelOscuro),
  calido('Cálido', LockspirePalettes.calido, LockspirePalettes.calidoOscuro),
  menta('Menta', LockspirePalettes.menta, LockspirePalettes.mentaOscuro),
  lavanda(
    'Lavanda',
    LockspirePalettes.lavanda,
    LockspirePalettes.lavandaOscuro,
  );

  final String displayName;
  final LockspirePalette light;
  final LockspirePalette dark;

  const LockspireThemeFamily(this.displayName, this.light, this.dark);
}

/// `ThemeData` real construido a partir del sistema de diseño (ver
/// docs/design/README.md) para una [LockspirePalette].
abstract final class LockspireTheme {
  // Quicksand: títulos, nombre de la app, texto de botones.
  static const _headingFamily = 'Quicksand';
  // Karla: cuerpo de texto, labels, captions.
  static const _bodyFamily = 'Karla';

  // El doc de diseño dice "texto de botones: Quicksand" sin fijar un
  // tamaño propio — se usa el mismo tamaño que Body (15px) por legibilidad,
  // con peso 600 (llamativo sin llegar al 700 reservado para Display/Heading).
  static const _buttonTextStyle = TextStyle(
    fontFamily: _headingFamily,
    fontWeight: FontWeight.w600,
    fontSize: 15,
  );

  static final _cache = <LockspirePalette, ThemeData>{};

  /// `ThemeData` de [palette], construido una sola vez por paleta.
  static ThemeData of(LockspirePalette palette) =>
      _cache.putIfAbsent(palette, () => build(palette));

  static ThemeData build(LockspirePalette p) {
    final textTheme = TextTheme(
      // Display — Quicksand 700, 20px.
      headlineSmall: TextStyle(
        fontFamily: _headingFamily,
        fontWeight: FontWeight.w700,
        fontSize: 20,
        color: p.textPrimary,
      ),
      // Heading — Quicksand 700, 17px (también usado por AppBar).
      titleLarge: TextStyle(
        fontFamily: _headingFamily,
        fontWeight: FontWeight.w700,
        fontSize: 17,
        color: p.textPrimary,
      ),
      titleMedium: TextStyle(
        fontFamily: _headingFamily,
        fontWeight: FontWeight.w700,
        fontSize: 15,
        color: p.textPrimary,
      ),
      // Body — Karla 500, 15px. Estilo por defecto de Text() sin estilo propio.
      bodyMedium: TextStyle(
        fontFamily: _bodyFamily,
        fontWeight: FontWeight.w500,
        fontSize: 15,
        color: p.textPrimary,
      ),
      bodyLarge: TextStyle(
        fontFamily: _bodyFamily,
        fontWeight: FontWeight.w500,
        fontSize: 16,
        color: p.textPrimary,
      ),
      // Caption — Karla 500, 13px.
      bodySmall: TextStyle(
        fontFamily: _bodyFamily,
        fontWeight: FontWeight.w500,
        fontSize: 13,
        color: p.textSecondary,
      ),
      // Label — Karla 600, 12px.
      labelMedium: TextStyle(
        fontFamily: _bodyFamily,
        fontWeight: FontWeight.w600,
        fontSize: 12,
        color: p.textSecondary,
      ),
    );

    final colorScheme = ColorScheme(
      brightness: p.brightness,
      primary: p.accentDefault,
      onPrimary: p.onAccent,
      secondary: p.accentSecondary,
      onSecondary: p.onAccent,
      error: p.danger,
      onError: p.isDark ? p.bgPage : Colors.white,
      surface: p.bgSurface,
      onSurface: p.textPrimary,
      onSurfaceVariant: p.textSecondary,
      surfaceContainerLowest: p.bgPage,
      surfaceContainerLow: p.bgSurface,
      surfaceContainer: p.bgSurface,
      surfaceContainerHigh: p.bgSurface,
      surfaceContainerHighest: p.bgSurfaceSubtle,
      outline: p.textPlaceholder,
      outlineVariant: p.bgSurfaceSubtle,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: p.brightness,
      scaffoldBackgroundColor: p.bgPage,
      fontFamily: _bodyFamily,
      textTheme: textTheme,
      colorScheme: colorScheme,
      extensions: [p],
      appBarTheme: AppBarTheme(
        backgroundColor: p.bgPage,
        foregroundColor: p.textPrimary,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: textTheme.titleLarge,
      ),
      cardTheme: CardThemeData(
        color: p.bgSurface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(LockspireRadius.lg),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: p.bgSurface,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: textTheme.titleLarge,
        contentTextStyle: textTheme.bodyMedium,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: p.textPrimary,
        contentTextStyle: textTheme.bodyMedium?.copyWith(color: p.bgPage),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: ButtonStyle(
          textStyle: const WidgetStatePropertyAll(_buttonTextStyle),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(LockspireRadius.pill),
            ),
          ),
          padding: const WidgetStatePropertyAll(
            EdgeInsets.symmetric(
              horizontal: LockspireSpacing.lg,
              vertical: LockspireSpacing.md,
            ),
          ),
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.disabled)) {
              return p.textPlaceholder;
            }
            if (states.contains(WidgetState.pressed)) {
              return p.accentHover;
            }
            return p.accentDefault;
          }),
          foregroundColor: WidgetStatePropertyAll(p.onAccent),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: ButtonStyle(
          textStyle: const WidgetStatePropertyAll(_buttonTextStyle),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(LockspireRadius.pill),
            ),
          ),
          padding: const WidgetStatePropertyAll(
            EdgeInsets.symmetric(
              horizontal: LockspireSpacing.lg,
              vertical: LockspireSpacing.md,
            ),
          ),
          side: WidgetStatePropertyAll(BorderSide(color: p.accentDefault)),
          foregroundColor: WidgetStatePropertyAll(p.accentDefault),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: ButtonStyle(
          textStyle: const WidgetStatePropertyAll(_buttonTextStyle),
          foregroundColor: WidgetStatePropertyAll(p.accentDefault),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: p.bgInput,
        hintStyle: TextStyle(fontFamily: _bodyFamily, color: p.textPlaceholder),
        labelStyle: textTheme.labelMedium,
        errorStyle: textTheme.bodySmall?.copyWith(color: p.danger),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(LockspireRadius.md),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(LockspireRadius.md),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(LockspireRadius.md),
          borderSide: BorderSide(color: p.accentDefault, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(LockspireRadius.md),
          borderSide: BorderSide(color: p.danger),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(LockspireRadius.md),
          borderSide: BorderSide(color: p.danger, width: 2),
        ),
      ),
    );
  }
}
