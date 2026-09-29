// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Gabriel Ángel Montoya Rico

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lockspire/features/vault/domain/master_password_reminder.dart';
import 'package:lockspire/features/vault/infrastructure/secure_storage_master_password_reminder_adapter.dart';
import 'package:lockspire/features/vault/infrastructure/secure_storage_password_unlock_history_adapter.dart';

/// Recordatorio de la contraseña maestra (ADR 0017), guardado en el
/// almacenamiento seguro del sistema, aquí simulado.
void main() {
  late Map<String, String> stored;
  const storage = FlutterSecureStorage();

  setUp(() {
    stored = {};
    FlutterSecureStorage.setMockInitialValues(stored);
  });

  group('Cada cuánto pedir la contraseña', () {
    const adapter = SecureStorageMasterPasswordReminderAdapter(storage);

    test('sin elegir, usa el valor por defecto', () async {
      expect(await adapter.load(), MasterPasswordReminder.defaultValue);
    });

    test('guarda y recupera lo elegido', () async {
      await adapter.save(MasterPasswordReminder.thirtyDays);

      expect(await adapter.load(), MasterPasswordReminder.thirtyDays);
    });

    test('un valor dañado cae en el valor por defecto', () async {
      stored['session.master_password_reminder'] = 'cada-siglo';

      expect(await adapter.load(), MasterPasswordReminder.defaultValue);
    });
  });

  group('Último desbloqueo con contraseña', () {
    const adapter = SecureStoragePasswordUnlockHistoryAdapter(storage);

    test('sin registro no hay fecha', () async {
      expect(await adapter.lastPasswordUnlock(), isNull);
    });

    test('guarda la fecha en UTC y la recupera igual', () async {
      final at = DateTime.utc(2026, 9, 29, 15, 30);

      await adapter.recordPasswordUnlock(at.toLocal());

      expect(await adapter.lastPasswordUnlock(), at);
      expect(stored['session.last_password_unlock'], endsWith('Z'));
    });

    test('una fecha dañada se ignora', () async {
      stored['session.last_password_unlock'] = 'ayer';

      expect(await adapter.lastPasswordUnlock(), isNull);
    });
  });
}
