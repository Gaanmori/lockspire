// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Lockspire

import 'package:flutter/material.dart';

import 'lockspire_colors.dart';
import 'lockspire_spacing.dart';

/// `ThemeData` real construido a partir del sistema de diseño (ver
/// docs/design/README.md) — reemplaza el `ColorScheme.fromSeed` de
/// ejemplo del scaffold de `flutter create`.
abstract final class LockspireTheme {
  // Quicksand: títulos, nombre de la app, texto de botones.
  static const _headingFamily = 'Quicksand';
  // Karla: cuerpo de texto, labels, captions.
  static const _bodyFamily = 'Karla';

  static final TextTheme _textTheme = TextTheme(
    // Display — Quicksand 700, 20px.
    headlineSmall: const TextStyle(
      fontFamily: _headingFamily,
      fontWeight: FontWeight.w700,
      fontSize: 20,
      color: LockspireColors.textPrimary,
    ),
    // Heading — Quicksand 700, 17px (también usado por AppBar).
    titleLarge: const TextStyle(
      fontFamily: _headingFamily,
      fontWeight: FontWeight.w700,
      fontSize: 17,
      color: LockspireColors.textPrimary,
    ),
    // Body — Karla 500, 15px. Estilo por defecto de Text() sin estilo propio.
    bodyMedium: const TextStyle(
      fontFamily: _bodyFamily,
      fontWeight: FontWeight.w500,
      fontSize: 15,
      color: LockspireColors.textPrimary,
    ),
    // Caption — Karla 500, 13px.
    bodySmall: const TextStyle(
      fontFamily: _bodyFamily,
      fontWeight: FontWeight.w500,
      fontSize: 13,
      color: LockspireColors.textSecondary,
    ),
    // Label — Karla 600, 12px.
    labelMedium: const TextStyle(
      fontFamily: _bodyFamily,
      fontWeight: FontWeight.w600,
      fontSize: 12,
      color: LockspireColors.textSecondary,
    ),
  );

  // El doc de diseño dice "texto de botones: Quicksand" sin fijar un
  // tamaño propio — se usa el mismo tamaño que Body (15px) por legibilidad,
  // con peso 600 (llamativo sin llegar al 700 reservado para Display/Heading).
  static const _buttonTextStyle = TextStyle(
    fontFamily: _headingFamily,
    fontWeight: FontWeight.w600,
    fontSize: 15,
  );

  static final ThemeData themeData = ThemeData(
    useMaterial3: true,
    scaffoldBackgroundColor: LockspireColors.bgPage,
    fontFamily: _bodyFamily,
    textTheme: _textTheme,
    colorScheme: const ColorScheme.light(
      primary: LockspireColors.accentDefault,
      onPrimary: Colors.white,
      secondary: LockspireColors.accentSecondary,
      onSecondary: Colors.white,
      error: LockspireColors.danger,
      onError: Colors.white,
      surface: LockspireColors.bgSurface,
      onSurface: LockspireColors.textPrimary,
      surfaceContainerHighest: LockspireColors.bgSurfaceSubtle,
      outline: LockspireColors.textPlaceholder,
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: LockspireColors.bgPage,
      foregroundColor: LockspireColors.textPrimary,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      titleTextStyle: _textTheme.titleLarge,
    ),
    cardTheme: CardThemeData(
      color: LockspireColors.bgSurface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(LockspireRadius.lg),
      ),
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
            return LockspireColors.textPlaceholder;
          }
          if (states.contains(WidgetState.pressed)) {
            return LockspireColors.accentHover;
          }
          return LockspireColors.accentDefault;
        }),
        foregroundColor: const WidgetStatePropertyAll(Colors.white),
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
        side: const WidgetStatePropertyAll(
          BorderSide(color: LockspireColors.accentDefault),
        ),
        foregroundColor: const WidgetStatePropertyAll(
          LockspireColors.accentDefault,
        ),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: LockspireColors.bgInput,
      hintStyle: TextStyle(
        fontFamily: _bodyFamily,
        color: LockspireColors.textPlaceholder,
      ),
      labelStyle: _textTheme.labelMedium,
      errorStyle: _textTheme.bodySmall?.copyWith(color: LockspireColors.danger),
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
        borderSide: const BorderSide(
          color: LockspireColors.accentDefault,
          width: 2,
        ),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(LockspireRadius.md),
        borderSide: const BorderSide(color: LockspireColors.danger),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(LockspireRadius.md),
        borderSide: const BorderSide(color: LockspireColors.danger, width: 2),
      ),
    ),
  );
}
