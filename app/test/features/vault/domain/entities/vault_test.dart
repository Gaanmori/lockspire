// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Gabriel Ángel Montoya Rico

import 'package:flutter_test/flutter_test.dart';
import 'package:lockspire/features/vault/domain/entities/vault.dart';
import 'package:lockspire/features/vault/domain/entities/vault_entry.dart';

final _created = DateTime.utc(2026, 1, 1);
final _now = DateTime.utc(2026, 9, 27, 12);

VaultEntry _entry(String id, {String? title}) => VaultEntry(
  id: id,
  type: VaultEntryType.password,
  title: title ?? id,
  createdAt: _created,
  modifiedAt: _created,
  fields: const {'username': 'yo', 'password': 'viejo'},
);

Vault _vault(List<VaultEntry> entries) =>
    Vault(vaultId: 'v', schemaVersion: 1, entries: entries);

void main() {
  group('Vault — operaciones sobre entradas (A2)', () {
    test('withEntryAdded y withEntriesAdded agregan al final sin tocar el '
        'resto', () {
      final vault = _vault([_entry('a')]);
      expect(vault.withEntryAdded(_entry('b')).entries.map((e) => e.id), [
        'a',
        'b',
      ]);
      expect(
        vault
            .withEntriesAdded([_entry('b'), _entry('c')])
            .entries
            .map((e) => e.id),
        ['a', 'b', 'c'],
      );
      expect(vault.entries, hasLength(1), reason: 'inmutable');
    });

    test('withEntryUpdated cambia título, campos y modifiedAt solo de esa '
        'entrada', () {
      final vault = _vault([_entry('a'), _entry('b')]);
      final updated = vault.withEntryUpdated(
        id: 'b',
        title: 'Banco',
        fields: const {'username': 'yo', 'password': 'nuevo'},
        now: _now,
      );
      final b = updated.entries[1];
      expect(b.title, 'Banco');
      expect(b.fields['password'], 'nuevo');
      expect(b.modifiedAt, _now);
      expect(b.createdAt, _created);
      expect(updated.entries[0].modifiedAt, _created);
    });

    test('withEntryDeleted deja un tombstone, no quita la entrada', () {
      final deleted = _vault([_entry('a')]).withEntryDeleted('a', now: _now);
      final a = deleted.entries.single;
      expect(a.deleted, isTrue);
      expect(a.deletedAt, _now);
      expect(a.modifiedAt, _now);
    });

    test('un id inexistente deja la bóveda igual', () {
      final vault = _vault([_entry('a')]);
      final entries = vault.withEntryDeleted('x', now: _now).entries;
      expect(entries.single.deleted, isFalse);
      expect(entries.single.modifiedAt, _created);
    });
  });
}
