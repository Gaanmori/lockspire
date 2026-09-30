// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Gabriel Ángel Montoya Rico

import 'package:flutter_test/flutter_test.dart';
import 'package:lockspire/features/vault/domain/entities/vault.dart';
import 'package:lockspire/features/vault/domain/entities/vault_entry.dart';

import '../../../../support/builders.dart';

final _created = DateTime.utc(2026, 1, 1);
final _now = DateTime.utc(2026, 9, 27, 12);

VaultEntry _entry(String id, {String? title}) => anEntry(
  id: id,
  title: title,
  createdAt: _created,
  username: 'yo',
  password: 'viejo',
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

  group('withFieldReplaced (ADR 0034)', () {
    test('cambia el campo y guarda el valor anterior, el más reciente '
        'primero y hasta 3', () {
      var vault = _vault([_entry('a'), _entry('b')]);
      for (final (i, value) in ['v1', 'v2', 'v3', 'v4'].indexed) {
        vault = vault.withFieldReplaced(
          id: 'a',
          field: 'password',
          value: value,
          now: _now.add(Duration(minutes: i)),
        );
      }

      final entry = vault.entries.first;
      expect(entry.fields['password'], 'v4');
      expect(entry.fields['username'], 'yo');
      expect(entry.fieldHistory['password']!.map((r) => r.value), [
        'v3',
        'v2',
        'v1',
      ]);
      expect(entry.modifiedAt, _now.add(const Duration(minutes: 3)));
      expect(vault.entries.last.fields['password'], 'viejo');
    });

    test('el mismo valor no deja historial ni cambia la fecha', () {
      final vault = _vault([_entry('a')]).withFieldReplaced(
        id: 'a',
        field: 'password',
        value: 'viejo',
        now: _now,
      );

      expect(vault.entries.single.fieldHistory, isEmpty);
      expect(vault.entries.single.modifiedAt, _created);
    });
  });
}
