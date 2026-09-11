// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Lockspire

import 'package:flutter_test/flutter_test.dart';
import 'package:lockspire/features/vault/application/password_generator.dart';

void main() {
  group('generatePassword', () {
    test('respeta la longitud pedida', () {
      expect(generatePassword(length: 12).length, 12);
      expect(generatePassword(length: 20).length, 20);
      expect(generatePassword(length: 32).length, 32);
    });

    test('longitud por defecto es 20', () {
      expect(generatePassword().length, 20);
    });

    test('no es determinista entre llamadas', () {
      final passwords = List.generate(20, (_) => generatePassword());
      expect(passwords.toSet().length, passwords.length);
    });

    test('incluye al menos un caracter de cada clase', () {
      final password = generatePassword(length: 40);

      expect(password, matches(RegExp(r'[a-z]')));
      expect(password, matches(RegExp(r'[A-Z]')));
      expect(password, matches(RegExp(r'[0-9]')));
      expect(password, matches(RegExp(r'[^a-zA-Z0-9]')));
    });
  });

  group('generateMemorablePassword', () {
    const wordList = ['forest', 'sir', 'passed', 'river', 'stone'];

    test('respeta el patrón Palabra1<dígito>(-Palabra)*', () {
      final password = generateMemorablePassword(
        wordList: wordList,
        targetLength: 25,
      );

      expect(password, matches(RegExp(r'^[A-Za-z]+[0-9](-[A-Za-z]+)*$')));
    });

    test('cada palabra generada pertenece a wordList', () {
      final password = generateMemorablePassword(
        wordList: wordList,
        targetLength: 25,
      );
      final parts = password.split('-');

      final firstWordWithoutDigit = parts[0].substring(0, parts[0].length - 1);
      expect(wordList, contains(firstWordWithoutDigit.toLowerCase()));
      for (final part in parts.skip(1)) {
        expect(wordList, contains(part.toLowerCase()));
      }
    });

    test('no supera targetLength (con margen suficiente para que quepa '
        'más de una palabra)', () {
      final password = generateMemorablePassword(
        wordList: wordList,
        targetLength: 25,
      );

      expect(password.length, lessThanOrEqualTo(25));
    });

    test('con targetLength muy chico igual devuelve al menos una palabra, '
        'aunque supere el objetivo', () {
      final password = generateMemorablePassword(
        wordList: const ['elephant'],
        targetLength: 1,
      );

      expect(password.split('-'), hasLength(1));
      expect(password, matches(RegExp(r'^[A-Za-z]+[0-9]$')));
    });

    test('usa el espacio disponible — con targetLength grande agrega '
        'más de una palabra', () {
      final password = generateMemorablePassword(
        wordList: wordList,
        targetLength: 30,
      );

      expect(password.split('-').length, greaterThan(1));
    });

    test('no es determinista entre llamadas', () {
      final passwords = List.generate(
        20,
        (_) => generateMemorablePassword(wordList: wordList, targetLength: 25),
      );
      expect(passwords.toSet().length, greaterThan(1));
    });
  });
}
