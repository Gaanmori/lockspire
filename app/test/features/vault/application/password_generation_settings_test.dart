// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Gabriel Ángel Montoya Rico

import 'package:flutter_test/flutter_test.dart';
import 'package:lockspire/features/vault/application/password_generation_settings.dart';

void main() {
  group('PasswordGenerationSettings (C1)', () {
    test('una entrada nueva arranca en "fácil de recordar", 20 caracteres', () {
      const s = PasswordGenerationSettings.forNewEntry;
      expect(s.mode, PasswordGenerationMode.memorable);
      expect(s.length, 20);
    });

    test('al editar restaura el modo y la longitud guardados', () {
      final s = PasswordGenerationSettings.fromFields({
        'password_gen_mode': 'random',
        'password_gen_param': '32',
      });
      expect(s.mode, PasswordGenerationMode.random);
      expect(s.length, 32);
    });

    test('sin metadata infiere aleatoria con la longitud de la contraseña, '
        'acotada al rango', () {
      expect(
        PasswordGenerationSettings.fromFields({'password': 'x' * 15}).length,
        15,
      );
      expect(
        PasswordGenerationSettings.fromFields({'password': 'x' * 3}).length,
        PasswordGenerationSettings.minLength,
      );
      expect(
        PasswordGenerationSettings.fromFields({'password': 'x' * 90}).length,
        PasswordGenerationSettings.maxLength,
      );
    });

    test('toFields guarda exactamente las claves de siempre', () {
      const s = PasswordGenerationSettings(
        mode: PasswordGenerationMode.memorable,
        length: 24,
      );
      expect(s.toFields(), {
        'password_gen_mode': 'memorable',
        'password_gen_param': '24',
      });
    });

    test('genera con la longitud pedida en modo aleatorio', () {
      const s = PasswordGenerationSettings(
        mode: PasswordGenerationMode.random,
        length: 30,
      );
      expect(s.generate(wordList: const ['uno']), hasLength(30));
    });
  });
}
