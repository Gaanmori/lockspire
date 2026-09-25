// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Lockspire

import 'package:flutter/material.dart';

import '../../../design/lockspire_colors.dart';
import '../../../design/lockspire_theme.dart';
import '../domain/appearance_preference.dart';

/// Paletas clara y oscura de una familia.
typedef PalettePair = ({LockspirePalette light, LockspirePalette dark});

/// Paletas para [family]. [systemArgb] es el color del sistema; solo lo usa
/// [ThemeFamilyId.sistema]. Si no hay color del sistema, se usa Cálido.
PalettePair palettesFor(ThemeFamilyId family, int? systemArgb) {
  switch (family) {
    case ThemeFamilyId.sistema when systemArgb != null:
      final seed = Color(systemArgb);
      return (
        light: LockspirePalette.fromSeed(seed, Brightness.light),
        dark: LockspirePalette.fromSeed(seed, Brightness.dark),
      );
    case ThemeFamilyId.sistema:
      return (
        light: LockspirePalettes.calido,
        dark: LockspirePalettes.calidoOscuro,
      );
    case ThemeFamilyId.calido || ThemeFamilyId.menta || ThemeFamilyId.lavanda:
      final fixed = LockspireThemeFamily.values.byName(family.name);
      return (light: fixed.light, dark: fixed.dark);
  }
}

/// Temas que usa `MaterialApp`.
typedef AppThemes = ({ThemeData light, ThemeData dark, ThemeMode mode});

/// Traduce la preferencia de dominio (sin Flutter) a tipos de Flutter. El
/// dominio no conoce `ThemeData`; esta es la única frontera entre ambos.
AppThemes resolveAppThemes(AppearancePreference preference, int? systemArgb) {
  final palettes = palettesFor(preference.family, systemArgb);
  return (
    light: LockspireTheme.of(palettes.light),
    dark: LockspireTheme.of(palettes.dark),
    mode: switch (preference.mode) {
      AppearanceMode.system => ThemeMode.system,
      AppearanceMode.light => ThemeMode.light,
      AppearanceMode.dark => ThemeMode.dark,
    },
  );
}
