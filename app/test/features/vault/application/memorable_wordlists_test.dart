// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Lockspire

import 'package:flutter_test/flutter_test.dart';
import 'package:lockspire/features/vault/application/memorable_wordlists.dart';

void main() {
  group('memorable_wordlists', () {
    for (final entry in {
      'spanishWordList': spanishWordList,
      'englishWordList': englishWordList,
    }.entries) {
      group(entry.key, () {
        test('tiene suficientes palabras para buena entropía', () {
          expect(entry.value.length, greaterThan(1000));
        });

        test('todas las palabras son minúscula de una pieza (ñ permitida, '
            'sin acentos/espacios/guiones — ver el doc comment del '
            'archivo)', () {
          for (final word in entry.value) {
            expect(
              word,
              matches(RegExp('^[a-zñ]+\$')),
              reason: '"$word" no calza con ^[a-zñ]+\$',
            );
          }
        });

        test('sin palabras repetidas', () {
          expect(entry.value.toSet().length, entry.value.length);
        });
      });
    }
  });
}
