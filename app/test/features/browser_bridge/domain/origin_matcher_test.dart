// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Gabriel Ángel Montoya Rico

import 'package:flutter_test/flutter_test.dart';
import 'package:lockspire/features/browser_bridge/domain/origin_matcher.dart';
import 'package:lockspire/features/vault/domain/entities/vault_entry.dart';

VaultEntry _entry(String? url, {bool deleted = false}) {
  final entry = VaultEntry.create(
    title: 'Ejemplo',
    fields: {'username': 'ana', 'password': 'x', 'url': ?url},
  );
  return deleted ? entry.copyWith(deleted: true) : entry;
}

void main() {
  group('linkedUrlForOrigin (ADR 0015)', () {
    test('quita solo un www. inicial y conserva esquema y puerto', () {
      expect(
        linkedUrlForOrigin('https://www.facebook.com'),
        'https://facebook.com',
      );
      expect(
        linkedUrlForOrigin('https://m.facebook.com'),
        'https://m.facebook.com',
      );
      expect(
        linkedUrlForOrigin('http://www.intranet.local:8080'),
        'http://intranet.local:8080',
      );
      // "www.com" no se reduce a "com".
      expect(linkedUrlForOrigin('https://www.com'), 'https://www.com');
    });

    test('la URL guardada coincide luego con www. y con otros subdominios', () {
      final entry = _entry(linkedUrlForOrigin('https://www.facebook.com'));
      expect(entryMatchesOrigin(entry, 'https://www.facebook.com'), isTrue);
      expect(entryMatchesOrigin(entry, 'https://m.facebook.com'), isTrue);
      expect(
        entryMatchesOrigin(entry, 'https://facebook.com.evil.io'),
        isFalse,
      );
    });
  });

  group('entryMatchesOrigin (ADR 0013)', () {
    test('mismo host coincide; subdominio del guardado también', () {
      final entry = _entry('https://example.com/login');
      expect(entryMatchesOrigin(entry, 'https://example.com'), isTrue);
      expect(entryMatchesOrigin(entry, 'https://login.example.com'), isTrue);
      expect(entryMatchesOrigin(entry, 'https://a.b.example.com'), isTrue);
    });

    test('nunca al revés ni por sufijo de texto', () {
      final entry = _entry('https://accounts.example.com');
      expect(entryMatchesOrigin(entry, 'https://example.com'), isFalse);
      expect(entryMatchesOrigin(entry, 'https://other.example.com'), isFalse);
      // "evilexample.com" termina en "example.com" pero no es subdominio.
      expect(
        entryMatchesOrigin(_entry('example.com'), 'https://evilexample.com'),
        isFalse,
      );
      expect(
        entryMatchesOrigin(
          _entry('example.com'),
          'https://example.com.evil.io',
        ),
        isFalse,
      );
    });

    test('sin esquema se asume https; sin mayúsculas ni punto final', () {
      expect(
        entryMatchesOrigin(_entry('Example.COM.'), 'https://example.com'),
        isTrue,
      );
      expect(
        entryMatchesOrigin(_entry('example.com'), 'http://example.com'),
        isFalse,
      );
    });

    test('https guardado nunca se rellena en http (downgrade)', () {
      expect(
        entryMatchesOrigin(_entry('https://example.com'), 'http://example.com'),
        isFalse,
      );
    });

    test('http guardado sí se rellena en https (mejora)', () {
      expect(
        entryMatchesOrigin(
          _entry('http://intranet.local'),
          'https://intranet.local',
        ),
        isTrue,
      );
      expect(
        entryMatchesOrigin(
          _entry('http://intranet.local'),
          'http://intranet.local',
        ),
        isTrue,
      );
    });

    test('puerto explícito en la entrada tiene que coincidir', () {
      final entry = _entry('https://localhost:8443');
      expect(entryMatchesOrigin(entry, 'https://localhost:8443'), isTrue);
      expect(entryMatchesOrigin(entry, 'https://localhost:9000'), isFalse);
      expect(entryMatchesOrigin(entry, 'https://localhost'), isFalse);
    });

    test('borradas, sin URL, URL no web u origen no web → no coinciden', () {
      expect(entryMatchesOrigin(_entry(null), 'https://example.com'), isFalse);
      expect(entryMatchesOrigin(_entry('   '), 'https://example.com'), isFalse);
      expect(
        entryMatchesOrigin(
          _entry('https://example.com', deleted: true),
          'https://example.com',
        ),
        isFalse,
      );
      expect(
        entryMatchesOrigin(_entry('ftp://example.com'), 'https://example.com'),
        isFalse,
      );
      expect(
        entryMatchesOrigin(
          _entry('https://example.com'),
          'file:///example.com',
        ),
        isFalse,
      );
    });
  });
}
