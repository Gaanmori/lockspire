// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Gabriel Ángel Montoya Rico

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lockspire/l10n/l10n.dart';

/// Textos traducidos (ADR 0032). `app_es.arb` es la plantilla: todo idioma
/// tiene sus mismas claves, con los mismos parámetros, y ninguno vacío.
void main() {
  Map<String, dynamic> arb(String locale) =>
      jsonDecode(File('lib/l10n/app_$locale.arb').readAsStringSync())
          as Map<String, dynamic>;

  Set<String> keysOf(Map<String, dynamic> m) =>
      m.keys.where((k) => !k.startsWith('@')).toSet();

  // Nombres de parámetro: "{nombre}" o "{nombre, plural, ...}". Las formas
  // de un plural ("=1{...}", "other{...}") no son parámetros.
  final placeholder = RegExp(r'(?<![=\w])\{(\w+)[},]');
  Set<String> paramsOf(String text) =>
      placeholder.allMatches(text).map((m) => m.group(1)!).toSet();

  final template = arb('es');
  final locales = [
    for (final l in AppLocalizations.supportedLocales) l.languageCode,
  ];

  test('cada idioma soportado tiene su archivo', () {
    expect(locales, containsAll(['es', 'en']));
    for (final locale in locales) {
      expect(File('lib/l10n/app_$locale.arb').existsSync(), isTrue);
    }
  });

  for (final locale in locales.where((l) => l != 'es')) {
    test('$locale tiene exactamente las claves de es', () {
      final other = arb(locale);
      expect(keysOf(other), keysOf(template));
    });

    test('$locale usa los mismos parámetros que es', () {
      final other = arb(locale);
      final mismatches = <String>[
        for (final key in keysOf(template))
          if (other[key] is String &&
              !const SetEquality().equals(
                paramsOf(template[key] as String),
                paramsOf(other[key] as String),
              ))
            key,
      ];
      expect(mismatches, isEmpty);
    });
  }

  test('ningún texto está vacío', () {
    for (final locale in locales) {
      final m = arb(locale);
      for (final key in keysOf(m)) {
        expect((m[key] as String).trim(), isNotEmpty, reason: '$locale:$key');
      }
    }
  });
}

class SetEquality {
  const SetEquality();
  bool equals(Set<String> a, Set<String> b) =>
      a.length == b.length && a.containsAll(b);
}
