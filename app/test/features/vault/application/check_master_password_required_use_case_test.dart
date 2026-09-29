// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Gabriel Ángel Montoya Rico

import 'package:flutter_test/flutter_test.dart';
import 'package:lockspire/features/vault/application/check_master_password_required_use_case.dart';
import 'package:lockspire/features/vault/domain/master_password_reminder.dart';
import 'package:lockspire/features/vault/domain/ports/password_unlock_history_port.dart';

import '../../../support/fakes/vault_fakes.dart';

class _ThrowingHistory implements PasswordUnlockHistoryPort {
  @override
  Future<DateTime?> lastPasswordUnlock() => throw StateError('sin storage');

  @override
  Future<void> recordPasswordUnlock(DateTime at) async {}
}

void main() {
  var now = DateTime.utc(2026, 9, 25, 12);

  test('evalúa con los datos y la hora de cada llamada, sin cachear', () async {
    final history = FakePasswordUnlockHistoryPort();
    final check = CheckMasterPasswordRequiredUseCase(
      settings: FakeMasterPasswordReminderSettingsPort(),
      history: history,
      now: () => now,
    );

    expect(await check(), isTrue, reason: 'sin registro');

    await history.recordPasswordUnlock(now);
    expect(await check(), isFalse, reason: 'recién desbloqueado');

    now = now.add(const Duration(days: 14));
    expect(await check(), isTrue, reason: 'venció con la app abierta');
  });

  test('usa el plazo elegido', () async {
    final base = DateTime.utc(2026, 9, 1);
    final check = CheckMasterPasswordRequiredUseCase(
      settings: FakeMasterPasswordReminderSettingsPort(
        MasterPasswordReminder.sevenDays,
      ),
      history: FakePasswordUnlockHistoryPort(base),
      now: () => base.add(const Duration(days: 8)),
    );
    expect(await check(), isTrue);
  });

  test('si no se puede leer el registro, exige la contraseña', () async {
    final check = CheckMasterPasswordRequiredUseCase(
      settings: FakeMasterPasswordReminderSettingsPort(),
      history: _ThrowingHistory(),
      now: () => now,
    );
    expect(await check(), isTrue);
  });
}
