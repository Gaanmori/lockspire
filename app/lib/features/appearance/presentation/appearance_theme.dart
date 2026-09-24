// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Lockspire

import 'package:flutter/material.dart';

import '../../../design/lockspire_theme.dart';
import '../domain/appearance_preference.dart';

/// Traduce la preferencia de dominio (sin Flutter) a tipos de Flutter. El
/// dominio no conoce `ThemeData`; esta es la única frontera entre ambos.
extension AppearancePreferenceTheme on AppearancePreference {
  LockspireThemeFamily get themeFamily =>
      LockspireThemeFamily.values.byName(family.name);

  ThemeData get lightTheme => LockspireTheme.of(themeFamily.light);

  ThemeData get darkTheme => LockspireTheme.of(themeFamily.dark);

  ThemeMode get themeMode => switch (mode) {
    AppearanceMode.system => ThemeMode.system,
    AppearanceMode.light => ThemeMode.light,
    AppearanceMode.dark => ThemeMode.dark,
  };
}
