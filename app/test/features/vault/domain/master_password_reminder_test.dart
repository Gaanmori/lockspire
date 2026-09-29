// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Gabriel Ángel Montoya Rico

import 'package:flutter_test/flutter_test.dart';
import 'package:lockspire/features/vault/domain/master_password_reminder.dart';

void main() {
  final base = DateTime.utc(2026, 9, 1, 12);
  const fourteen = Duration(days: 14);

  bool required(DateTime? last, DateTime now) => isMasterPasswordRequiredAt(
    lastPasswordUnlock: last,
    now: now,
    interval: fourteen,
  );

  test('opciones 7, 14 y 30 días; 14 por defecto', () {
    expect(MasterPasswordReminder.values.map((r) => r.interval.inDays), [
      7,
      14,
      30,
    ]);
    expect(MasterPasswordReminder.defaultValue.interval.inDays, 14);
  });

  test('sin registro previo → pide la contraseña', () {
    expect(required(null, base), isTrue);
  });

  test('dentro del plazo → no la pide', () {
    expect(required(base, base), isFalse);
    expect(
      required(base, base.add(fourteen - const Duration(seconds: 1))),
      isFalse,
    );
  });

  test('al cumplirse el plazo exacto o después → la pide', () {
    expect(required(base, base.add(fourteen)), isTrue);
    expect(required(base, base.add(const Duration(days: 60))), isTrue);
  });

  test('reloj atrasado (registro en el futuro) → la pide', () {
    expect(required(base, base.subtract(const Duration(minutes: 1))), isTrue);
  });
}
