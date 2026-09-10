// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Lockspire

import 'package:flutter_test/flutter_test.dart';
import 'package:lockspire/features/vault/domain/entities/vault_entry.dart';

void main() {
  group('VaultEntry.create', () {
    test('genera IDs distintos en llamadas sucesivas', () {
      final a = VaultEntry.create(title: 'A');
      final b = VaultEntry.create(title: 'B');

      expect(a.id, isNot(b.id));
    });

    test('siempre crea entradas de tipo password en esta pasada', () {
      final entry = VaultEntry.create(title: 'Ejemplo');

      expect(entry.type, VaultEntryType.password);
      expect(entry.deleted, isFalse);
      expect(entry.deletedAt, isNull);
    });

    test('createdAt y modifiedAt coinciden al crear', () {
      final entry = VaultEntry.create(title: 'Ejemplo');

      expect(entry.createdAt, entry.modifiedAt);
    });
  });

  group('VaultEntry.fieldHistory (ADR 0009)', () {
    test('round-trip de toJson/fromJson conserva el historial por campo', () {
      final entry = VaultEntry(
        id: 'a',
        type: VaultEntryType.password,
        title: 'Banco',
        createdAt: DateTime.utc(2026, 1, 1),
        modifiedAt: DateTime.utc(2026, 2, 1),
        fields: const {'password': 'actual'},
        fieldHistory: {
          'password': [
            FieldHistoryRecord(
              value: 'anterior',
              replacedAt: DateTime.utc(2026, 1, 15),
            ),
          ],
          titleFieldKey: [
            FieldHistoryRecord(
              value: 'Título viejo',
              replacedAt: DateTime.utc(2026, 1, 10),
            ),
          ],
        },
      );

      final roundTripped = VaultEntry.fromJson(entry.toJson());

      expect(roundTripped.fieldHistory.keys, entry.fieldHistory.keys);
      expect(roundTripped.fieldHistory['password']!.single.value, 'anterior');
      expect(
        roundTripped.fieldHistory['password']!.single.replacedAt,
        DateTime.utc(2026, 1, 15),
      );
      expect(
        roundTripped.fieldHistory[titleFieldKey]!.single.value,
        'Título viejo',
      );
    });

    test('una entrada sin historial (o serializada antes de ADR 0009) lee '
        'fieldHistory vacío, retrocompatible', () {
      final entry = VaultEntry(
        id: 'a',
        type: VaultEntryType.password,
        title: 'Banco',
        createdAt: DateTime.utc(2026, 1, 1),
        modifiedAt: DateTime.utc(2026, 1, 1),
      );
      final json = entry.toJson();

      expect(json.containsKey('field_history'), isFalse);
      expect(VaultEntry.fromJson(json).fieldHistory, isEmpty);
    });
  });
}
