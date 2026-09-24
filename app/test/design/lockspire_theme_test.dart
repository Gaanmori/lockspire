// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Lockspire

import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lockspire/design/lockspire_colors.dart';
import 'package:lockspire/design/lockspire_theme.dart';

/// Contraste WCAG 2.x entre dos colores opacos.
double _contrast(Color a, Color b) {
  double channel(double c) =>
      c <= 0.04045 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4).toDouble();
  double luminance(Color c) =>
      0.2126 * channel(c.r) + 0.7152 * channel(c.g) + 0.0722 * channel(c.b);
  final la = luminance(a);
  final lb = luminance(b);
  return (max(la, lb) + 0.05) / (min(la, lb) + 0.05);
}

void main() {
  final all = {
    for (final family in LockspireThemeFamily.values) ...{
      '${family.name} claro': family.light,
      '${family.name} oscuro': family.dark,
    },
  };

  test('hay 6 temas: 3 claros y 3 oscuros', () {
    expect(all, hasLength(6));
    expect(all.values.where((p) => !p.isDark), hasLength(3));
    expect(all.values.where((p) => p.isDark), hasLength(3));
  });

  test('cada ThemeData lleva su paleta y el brillo correcto', () {
    for (final MapEntry(key: name, value: palette) in all.entries) {
      final theme = LockspireTheme.of(palette);
      expect(theme.extension<LockspirePalette>(), same(palette), reason: name);
      expect(theme.brightness, palette.brightness, reason: name);
      expect(theme.colorScheme.brightness, palette.brightness, reason: name);
      expect(theme.scaffoldBackgroundColor, palette.bgPage, reason: name);
    }
  });

  test('LockspireTheme.of reutiliza el ThemeData de cada paleta', () {
    final palette = LockspirePalettes.menta;
    expect(LockspireTheme.of(palette), same(LockspireTheme.of(palette)));
  });

  // Umbrales WCAG: 4.5 para texto normal, 3 para texto grande / controles.
  test('contraste legible en todos los temas', () {
    for (final MapEntry(key: name, value: p) in all.entries) {
      expect(
        _contrast(p.textPrimary, p.bgPage),
        greaterThanOrEqualTo(7),
        reason: '$name: texto principal sobre la página',
      );
      expect(
        _contrast(p.textPrimary, p.bgSurface),
        greaterThanOrEqualTo(7),
        reason: '$name: texto principal sobre tarjetas',
      );
      expect(
        _contrast(p.textSecondary, p.bgSurface),
        greaterThanOrEqualTo(3),
        reason: '$name: texto secundario sobre tarjetas',
      );
      expect(
        _contrast(p.onAccent, p.accentDefault),
        greaterThanOrEqualTo(3),
        reason: '$name: texto de botones sobre el acento',
      );
      expect(
        _contrast(p.accentDefault, p.bgPage),
        greaterThanOrEqualTo(2.5),
        reason: '$name: botones con borde de acento sobre la página',
      );
    }
  });
}
