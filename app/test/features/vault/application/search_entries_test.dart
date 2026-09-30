// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Gabriel Ángel Montoya Rico

import 'package:flutter_test/flutter_test.dart';
import 'package:lockspire/features/vault/application/search_entries.dart';
import 'package:lockspire/features/vault/domain/entities/entry_fields.dart';

import '../../../support/builders.dart';

/// La búsqueda de la lista de la bóveda (P3).
void main() {
  final entries = [
    anEntry(
      id: '1',
      title: 'banco',
      username: 'ana',
      url: 'https://banco.example',
    ),
    anEntry(id: '2', title: 'Amazon', username: 'compras@correo.example'),
    anEntry(
      id: '3',
      title: 'Visa',
      fields: {EntryFields.cardHolder: 'ANA PÉREZ'},
    ),
    anEntry(id: '4', title: 'Borrada', deleted: true),
  ];

  List<String> titles(String query) =>
      searchEntries(entries, query).map((e) => e.title).toList();

  test('sin búsqueda: todas las visibles, por título sin distinguir '
      'mayúsculas', () {
    expect(titles(''), ['Amazon', 'banco', 'Visa']);
  });

  test('busca en título, usuario, titular y sitios, sin distinguir '
      'mayúsculas ni espacios de los extremos', () {
    expect(titles('  ANA '), ['banco', 'Visa']);
    expect(titles('correo'), ['Amazon']);
    expect(titles('banco.example'), ['banco']);
  });

  test('las borradas nunca aparecen', () {
    expect(titles('borrada'), isEmpty);
  });
}
