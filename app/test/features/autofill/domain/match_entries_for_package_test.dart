// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Lockspire

import 'package:flutter_test/flutter_test.dart';
import 'package:lockspire/features/autofill/domain/match_entries_for_package.dart';
import 'package:lockspire/features/vault/domain/entities/vault_entry.dart';

VaultEntry _entry(String title, {String? url, bool deleted = false}) {
  final now = DateTime.utc(2026, 1, 1);
  return VaultEntry(
    id: title,
    type: VaultEntryType.password,
    title: title,
    createdAt: now,
    modifiedAt: now,
    deleted: deleted,
    fields: url == null ? const {} : {'url': url},
  );
}

void main() {
  group('matchEntriesForPackage', () {
    test('pone primero la entrada cuyo título coincide con el paquete', () {
      final entries = [_entry('Netflix'), _entry('Frisby')];

      final result = matchEntriesForPackage(
        entries: entries,
        packageName: 'com.frisby.frisby',
      );

      expect(result.map((e) => e.title), ['Frisby', 'Netflix']);
    });

    test('coincide también contra la URL de la entrada', () {
      final entries = [
        _entry('Mi banco', url: 'https://frisby.com.co/login'),
        _entry('Otra app'),
      ];

      final result = matchEntriesForPackage(
        entries: entries,
        packageName: 'com.frisby.frisby',
      );

      expect(result.first.title, 'Mi banco');
    });

    test('sin ninguna coincidencia devuelve la lista completa igual', () {
      final entries = [_entry('Netflix'), _entry('Spotify')];

      final result = matchEntriesForPackage(
        entries: entries,
        packageName: 'com.example.randomapp',
      );

      expect(result.length, 2);
      expect(result.map((e) => e.title), containsAll(['Netflix', 'Spotify']));
    });

    test('no es sensible a mayúsculas/minúsculas', () {
      final entries = [_entry('FRISBY')];

      final result = matchEntriesForPackage(
        entries: entries,
        packageName: 'com.frisby.frisby',
      );

      expect(result.first.title, 'FRISBY');
    });

    test('ignora segmentos genéricos del paquete (com, app, etc.)', () {
      final entries = [_entry('Com'), _entry('App')];

      final result = matchEntriesForPackage(
        entries: entries,
        packageName: 'com.app.io',
      );

      // Ningún segmento cuenta como señal real — ninguna entrada debería
      // quedar "matcheada" por casualidad de nombre.
      expect(result.length, 2);
    });

    test('excluye entradas borradas', () {
      final entries = [_entry('Frisby', deleted: true), _entry('Netflix')];

      final result = matchEntriesForPackage(
        entries: entries,
        packageName: 'com.frisby.frisby',
      );

      expect(result.length, 1);
      expect(result.first.title, 'Netflix');
    });
  });
}
