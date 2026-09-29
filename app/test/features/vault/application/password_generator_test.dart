// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Gabriel Ángel Montoya Rico

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
    // Mismo set que `_symbols` en password_generator.dart — los
    // separadores entre palabras salen de acá, uno independiente por
    // hueco (no siempre el mismo símbolo).
    final separatorClass = RegExp(r'[!@#$%^&*()\-_=+\[\]{}]');

    test('respeta el patrón Palabra1<dígito+>(<símbolo>Palabra<dígito*>)* '
        '(los dígitos de más al final de cualquier palabra son relleno de '
        'longitud, ver el doc comment del generador)', () {
      final password = generateMemorablePassword(
        wordList: wordList,
        targetLength: 25,
      );

      expect(
        password,
        matches(
          RegExp(
            r'^[A-Za-z]+[0-9]+(?:[!@#$%^&*()\-_=+\[\]{}][A-Za-z]+[0-9]*)*$',
          ),
        ),
      );
    });

    test('cada palabra generada (sin los dígitos de relleno) pertenece a '
        'wordList', () {
      final password = generateMemorablePassword(
        wordList: wordList,
        targetLength: 25,
      );
      final parts = password.split(separatorClass);
      final trailingDigits = RegExp(r'[0-9]+$');

      for (final part in parts) {
        final word = part.replaceFirst(trailingDigits, '');
        expect(wordList, contains(word.toLowerCase()));
      }
    });

    test('usa separadores distintos entre sí en distintos huecos (con '
        'suficientes palabras, no siempre sale el mismo símbolo)', () {
      // Con targetLength generoso caben varias palabras — sobre 30
      // intentos, se espera ver más de un símbolo distinto de separador
      // salvo mala suerte estadística extrema (18 símbolos posibles).
      final separators = <String>{};
      for (var i = 0; i < 30; i++) {
        final password = generateMemorablePassword(
          wordList: wordList,
          targetLength: 30,
        );
        separators.addAll(
          separatorClass.allMatches(password).map((m) => m.group(0)!),
        );
      }
      expect(separators.length, greaterThan(1));
    });

    test('siempre da exactamente targetLength caracteres (relleno con '
        'dígitos si no entra otra palabra completa) — pedido explícito '
        'del usuario', () {
      for (final targetLength in [12, 16, 20, 25, 30, 40]) {
        final password = generateMemorablePassword(
          wordList: wordList,
          targetLength: targetLength,
        );
        expect(
          password.length,
          targetLength,
          reason: 'targetLength=$targetLength',
        );
      }
    });

    test('con targetLength muy chico (menor que la primera palabra sola) '
        'no hay dígitos de relleno de más y el resultado supera el '
        'objetivo en vez de cortar la palabra', () {
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

      expect(password.split(separatorClass).length, greaterThan(1));
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
