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
}
