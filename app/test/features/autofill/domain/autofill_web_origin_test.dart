// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Gabriel Ángel Montoya Rico

import 'package:flutter_test/flutter_test.dart';
import 'package:lockspire/features/autofill/domain/autofill_web_origin.dart';
import 'package:lockspire/features/vault/domain/entities/vault_entry.dart';

import '../../../support/builders.dart';

VaultEntry _entry(String title, {String? url, bool deleted = false}) => anEntry(
  title: title,
  username: 'yo',
  password: 'x',
  url: url,
  deleted: deleted,
);

void main() {
  group('webOriginFor (ADR 0020)', () {
    test('arma el origen con el esquema informado', () {
      expect(
        webOriginFor(webDomain: 'Login.Banco.com', webScheme: 'https'),
        'https://login.banco.com',
      );
    });

    test('sin esquema conocido asume http (protección contra downgrade)', () {
      expect(webOriginFor(webDomain: 'banco.com'), 'http://banco.com');
      expect(
        webOriginFor(webDomain: 'banco.com', webScheme: 'javascript'),
        'http://banco.com',
      );
    });

    test('sin dominio o con un dominio inválido no hay origen web', () {
      expect(webOriginFor(), isNull);
      expect(webOriginFor(webDomain: '  '), isNull);
      expect(webOriginFor(webDomain: 'banco.com/login'), isNull);
      expect(webOriginFor(webDomain: 'usuario@banco.com'), isNull);
      expect(webOriginFor(webDomain: 'banco.com?x=1'), isNull);
    });

    test('conserva un puerto explícito', () {
      expect(
        webOriginFor(webDomain: 'intranet.local:8443', webScheme: 'https'),
        'https://intranet.local:8443',
      );
    });
  });

  group('classifyEntryForOrigin (ADR 0020)', () {
    const origin = 'https://login.banco.com';

    test('mismo sitio o subdominio → coincide', () {
      expect(
        classifyEntryForOrigin(_entry('Banco', url: 'banco.com'), origin),
        EntrySiteMatch.matches,
      );
      expect(
        classifyEntryForOrigin(
          _entry('Banco', url: 'https://login.banco.com/entrar'),
          origin,
        ),
        EntrySiteMatch.matches,
      );
    });

    test('la página falsa no coincide con la entrada del banco', () {
      expect(
        classifyEntryForOrigin(
          _entry('Banco', url: 'banco.com'),
          'https://banco-falso.com',
        ),
        EntrySiteMatch.otherSite,
      );
      expect(
        classifyEntryForOrigin(
          _entry('Banco', url: 'banco.com'),
          'https://banco.com.atacante.io',
        ),
        EntrySiteMatch.otherSite,
      );
    });

    test('una entrada https no coincide con una página http (downgrade)', () {
      expect(
        classifyEntryForOrigin(
          _entry('Banco', url: 'https://banco.com'),
          'http://banco.com',
        ),
        EntrySiteMatch.otherSite,
      );
    });

    test('sin URL guardada → sin sitio', () {
      expect(
        classifyEntryForOrigin(_entry('Banco'), origin),
        EntrySiteMatch.noSite,
      );
      expect(
        classifyEntryForOrigin(_entry('Banco', url: '  '), origin),
        EntrySiteMatch.noSite,
      );
    });
  });

  group('sortEntriesForOrigin', () {
    test('las del sitio primero, sin ocultar ni reordenar el resto, y sin '
        'borradas', () {
      final entries = [
        _entry('Otro', url: 'otro.com'),
        _entry('Sin sitio'),
        _entry('Banco', url: 'banco.com'),
        _entry('Borrada', url: 'banco.com', deleted: true),
      ];
      final sorted = sortEntriesForOrigin(
        entries: entries,
        origin: 'https://banco.com',
      );
      expect(sorted.map((e) => e.title), ['Banco', 'Otro', 'Sin sitio']);
    });
  });

  test('knownBrowserName nombra navegadores conocidos', () {
    expect(knownBrowserName('com.android.chrome'), 'Chrome');
    expect(knownBrowserName('com.crunchyroll.crunchyroid'), isNull);
  });
}
