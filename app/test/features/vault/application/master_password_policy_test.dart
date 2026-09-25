// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Lockspire

import 'package:flutter_test/flutter_test.dart';
import 'package:lockspire/features/vault/application/master_password_policy.dart';

void main() {
  group('checkNewMasterPassword (ADR 0018)', () {
    test('rechaza menos de 12 caracteres', () {
      expect(
        checkNewMasterPassword('12345678'),
        MasterPasswordProblem.tooShort,
      );
      expect(checkNewMasterPassword('Ab1!xyz'), MasterPasswordProblem.tooShort);
    });

    test('rechaza contraseñas largas pero repetitivas', () {
      expect(
        checkNewMasterPassword('aaaaaaaaaaaaaaaa'),
        MasterPasswordProblem.tooRepetitive,
      );
      expect(
        checkNewMasterPassword('abababababab'),
        MasterPasswordProblem.tooRepetitive,
      );
    });

    test('rechaza 12 dígitos: largo suficiente pero poca entropía', () {
      expect(
        checkNewMasterPassword('198403271234'),
        MasterPasswordProblem.tooWeak,
      );
    });

    test('acepta contraseñas fuertes', () {
      expect(checkNewMasterPassword('correcto caballo batería'), isNull);
      expect(checkNewMasterPassword('Tr3s-Tigres!Trigo'), isNull);
    });

    test('cada problema tiene un mensaje', () {
      for (final problem in MasterPasswordProblem.values) {
        expect(describeMasterPasswordProblem(problem), isNotEmpty);
      }
    });
  });
}
