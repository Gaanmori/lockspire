// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Gabriel Ángel Montoya Rico

import 'package:flutter_test/flutter_test.dart';
import 'package:lockspire/features/vault/application/password_strength_estimator.dart';

void main() {
  group('estimatePasswordStrength', () {
    test('string vacío no lanza, nivel débil, tiempo instantáneo', () {
      final estimate = estimatePasswordStrength('');

      expect(estimate.level, PasswordStrengthLevel.weak);
      expect(estimate.bits, 0);
      expect(estimate.crackTimeLabel, 'instantáneo');
    });

    test('solo minúsculas y corta -> weak', () {
      final estimate = estimatePasswordStrength('abcd');

      expect(estimate.level, PasswordStrengthLevel.weak);
    });

    test('combinación de las 4 clases y larga -> strong', () {
      final estimate = estimatePasswordStrength('Tr9#kP2\$mZ7!qL4@wX1&');

      expect(estimate.level, PasswordStrengthLevel.strong);
      expect(estimate.bits, greaterThanOrEqualTo(70));
    });

    test('nivel intermedio (fair) entre los dos umbrales', () {
      // Combina clases pero corta: ~35-70 bits esperados.
      final estimate = estimatePasswordStrength('Ab3xQ9');

      expect(estimate.level, PasswordStrengthLevel.fair);
    });

    test('tiempo de descifrado escala con la longitud/variedad', () {
      final weak = estimatePasswordStrength('abcd');
      final strong = estimatePasswordStrength('Tr9#kP2\$mZ7!qL4@wX1&');

      expect(strong.bits, greaterThan(weak.bits));
    });

    test('detecta el patrón "fácil de recordar" y estima por cantidad de '
        'palabras + separadores, no por clase de caracteres '
        '(ver password_generator.dart)', () {
      // 2 palabras — bits bajos aunque el string "se vea" largo/variado
      // (mayúsculas + minúsculas + dígito + símbolo): esa es
      // justamente la limitación que se corrige acá, ver el doc
      // comment de estimatePasswordStrength.
      final estimate = estimatePasswordStrength('Forest5-River');

      expect(estimate.level, PasswordStrengthLevel.weak);
      expect(estimate.bits, lessThan(35));
    });

    test(
      'dígitos de relleno al final de una palabra (ver '
      'generateMemorablePassword) suman entropía real, no son cosméticos',
      () {
        final withoutPadding = estimatePasswordStrength('Forest5-River');
        final withPadding = estimatePasswordStrength('Forest5-River42');

        expect(withPadding.bits, greaterThan(withoutPadding.bits));
      },
    );

    test('patrón memorable de una sola palabra -> weak', () {
      final estimate = estimatePasswordStrength('Forest5');

      expect(estimate.level, PasswordStrengthLevel.weak);
    });

    test('patrón memorable con suficientes palabras llega a fair', () {
      final estimate = estimatePasswordStrength('Forest5-River-Stone');

      expect(estimate.level, PasswordStrengthLevel.fair);
    });

    test('separadores no siempre el mismo símbolo — reconoce el patrón '
        'igual, y la entropía extra de los separadores puede llegar a '
        'strong con suficientes palabras', () {
      final estimate = estimatePasswordStrength(
        'Forest5!River&Stone#Sir\$Passed*Frost=Cloud',
      );

      expect(estimate.level, PasswordStrengthLevel.strong);
    });

    test('un string que no calza con el patrón memorable exacto (dígito en '
        'otra posición) usa la estimación por clase de caracteres', () {
      final estimate = estimatePasswordStrength('Ab3xQ9');

      expect(estimate.level, PasswordStrengthLevel.fair);
    });

    test('formatea el tiempo en distintas escalas legibles', () {
      expect(estimatePasswordStrength('a').crackTimeLabel, 'instantáneo');
      expect(
        estimatePasswordStrength('abcdefgh').crackTimeLabel,
        anyOf(contains('segundos'), contains('minutos'), contains('horas')),
      );
      expect(
        estimatePasswordStrength('Tr9#kP2\$mZ7!qL4@wX1&Yh6^Bn3').crackTimeLabel,
        anyOf(contains('siglos'), contains('millones de años')),
      );
    });
  });
}
