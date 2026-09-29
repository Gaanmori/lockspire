// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Gabriel Ángel Montoya Rico

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Los textos de la app están en español neutro con "usted" (revisión
/// 2026-09-25, hallazgo C4, decisión del usuario). Este test revisa los
/// literales de `lib/` y falla si aparece voseo ("Ingresá", "podés") o tuteo
/// ("tu bóveda", "puedes"). Los comentarios no cuentan.
void main() {
  final literal = RegExp(r"'(?:[^'\\]|\\.)*'");
  // Límites Unicode: el límite de palabra ASCII no trata "ó" o "é" como
  // letras ("abrió" daría un falso "abri").
  final secondPerson = RegExp(
    r'(?<!\p{L})(?:'
    // Voseo: solo formas con tilde, que no se confunden con la tercera
    // persona ("usá" frente a "usa").
    r'ingresá|elegí|usá|tocá|configurá|creá|activá|revisá|intentá|volvé|'
    r'probá|abrí|conectá|buscá|podés|tenés|querés|usás|olvidás|perdés|'
    r'sabés|'
    // Tuteo sin ambigüedad.
    r'puedes|tienes|quieres|olvidas|vas|debes|necesitas|eliges|'
    // Posesivos y pronombres de segunda persona.
    r'tu|tus|te|ti|vos|contigo'
    r')(?!\p{L})',
    caseSensitive: false,
    unicode: true,
  );

  test('los textos de lib/ no usan voseo ni tuteo (C4)', () {
    final offenders = <String>[];
    for (final file in Directory('lib').listSync(recursive: true)) {
      if (file is! File ||
          !file.path.endsWith('.dart') ||
          file.path.endsWith('.g.dart')) {
        continue;
      }
      final lines = file.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        final code = lines[i].trimLeft();
        if (code.startsWith('//')) continue;
        for (final match in literal.allMatches(lines[i])) {
          for (final word in secondPerson.allMatches(match.group(0)!)) {
            final w = word.group(0)!;
            if (w.isEmpty) continue;
            offenders.add('${file.path}:${i + 1}: "$w" en ${match.group(0)}');
          }
        }
      }
    }
    expect(offenders, isEmpty, reason: offenders.join('\n'));
  });
}
