// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Lockspire

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
