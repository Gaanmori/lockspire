// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Lockspire

import 'package:flutter_test/flutter_test.dart';
import 'package:lockspire/features/autofill/domain/match_entries_for_package.dart';
import 'package:lockspire/features/browser_bridge/domain/origin_matcher.dart';
import 'package:lockspire/features/vault/domain/entities/entry_fields.dart';
import 'package:lockspire/features/vault/domain/entities/vault.dart';
import 'package:lockspire/features/vault/domain/entities/vault_entry.dart';

VaultEntry _entry(
  String title,
  Map<String, String> fields, {
  VaultEntryType type = VaultEntryType.password,
}) => VaultEntry.create(title: title, type: type, fields: fields);

void main() {
  group('Campos repetibles (ADR 0025)', () {
    test('url, url_2, url_3… en orden, sin vacíos', () {
      final fields = {
        'url_3': 'https://c.test',
        'url': 'https://a.test',
        'url_2': '  ',
        'url_10': 'https://z.test',
        'urlx': 'no cuenta',
      };
      expect(repeatedValues(fields, EntryFields.url), [
        'https://a.test',
        'https://c.test',
        'https://z.test',
      ]);
    });

    test('guardar compacta los huecos', () {
      expect(repeatedFields(EntryFields.app, ['com.a', '', 'com.b']), {
        'app': 'com.a',
        'app_2': 'com.b',
      });
    });

    test('url_1 no es una key válida (el primero es url)', () {
      expect(repeatedIndex(EntryFields.url, 'url_1'), isNull);
      expect(repeatedIndex(EntryFields.url, 'url_2'), 1);
    });

    test('campos a medida visibles y ocultos, en orden', () {
      final fields = {
        'username': 'u',
        'custom:Pregunta': 'perro',
        'hidden:PIN': '1234',
      };
      final custom = customFieldsOf(fields);
      expect(custom.map((f) => (f.name, f.hidden)), [
        ('Pregunta', false),
        ('PIN', true),
      ]);
      expect(custom.last.key, 'hidden:PIN');
    });

    test('un tipo de entrada desconocido no impide abrir la bóveda', () {
      final json = _entry('x', {}).toJson()..['type'] = 'tipo_del_futuro';
      expect(VaultEntry.fromJson(json).type, VaultEntryType.password);
    });
  });

  group('Autofill con varios sitios y apps (ADR 0025)', () {
    test('la extensión rellena con cualquiera de los sitios', () {
      final entry = _entry('Amazon', {
        'url': 'https://amazon.com',
        'url_2': 'https://amazon.es',
      });
      expect(entryMatchesOrigin(entry, 'https://www.amazon.es'), isTrue);
      expect(entryMatchesOrigin(entry, 'https://amazon.com'), isTrue);
      expect(entryMatchesOrigin(entry, 'https://amazon.evil.test'), isFalse);
    });

    test('una tarjeta nunca se ofrece para un login', () {
      final card = _entry('Visa', {
        'url': 'https://banco.test',
      }, type: VaultEntryType.card);
      expect(entryMatchesOrigin(card, 'https://banco.test'), isFalse);
      expect(
        matchEntriesForPackage(entries: [card], packageName: 'com.banco'),
        isEmpty,
      );
    });

    test('en Android, el paquete exacto va primero, antes que el parecido '
        'por nombre', () {
      final parecido = _entry('Steam fan club', {});
      final exacto = _entry('Cuenta', {
        'app': 'com.otra',
        'app_2': 'com.valvesoftware.android.steam.community',
      });
      final otro = _entry('Otra', {});
      final sorted = matchEntriesForPackage(
        entries: [otro, parecido, exacto],
        packageName: 'com.valvesoftware.android.steam.community',
      );
      expect(sorted.map((e) => e.title), ['Cuenta', 'Steam fan club', 'Otra']);
    });
  });

  test('borrar varias entradas las deja como tombstones, sin tocar el resto '
      'ni las ya borradas', () {
    final a = _entry('a', {});
    final b = _entry('b', {});
    final c = _entry('c', {});
    final now = DateTime.utc(2026, 9, 28);
    final vault = Vault(
      vaultId: 'v',
      schemaVersion: 1,
      entries: [a, b, c],
    ).withEntriesDeleted({a.id, c.id}, now: now);
    expect(vault.entries.map((e) => e.deleted), [true, false, true]);
    expect(vault.entries.first.deletedAt, now);
  });
}
