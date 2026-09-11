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

    test('respeta el patrón Palabra1<dígito>-Palabra2-Palabra3', () {
      final password = generateMemorablePassword(wordList: wordList);

      expect(
        password,
        matches(RegExp(r'^[A-Za-z]+[0-9]-[A-Za-z]+-[A-Za-z]+$')),
      );
    });

    test('cada palabra generada pertenece a wordList', () {
      final password = generateMemorablePassword(wordList: wordList);
      final parts = password.split('-');

      expect(parts, hasLength(3));
      final firstWordWithoutDigit = parts[0].substring(0, parts[0].length - 1);
      expect(wordList, contains(firstWordWithoutDigit.toLowerCase()));
      expect(wordList, contains(parts[1].toLowerCase()));
      expect(wordList, contains(parts[2].toLowerCase()));
    });

    test('respeta wordCount pedido', () {
      final password = generateMemorablePassword(
        wordList: wordList,
        wordCount: 4,
      );

      expect(password.split('-'), hasLength(4));
    });

    test('no es determinista entre llamadas', () {
      final passwords = List.generate(
        20,
        (_) => generateMemorablePassword(wordList: wordList),
      );
      expect(passwords.toSet().length, greaterThan(1));
    });
  });
}
