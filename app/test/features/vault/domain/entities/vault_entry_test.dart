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
}
