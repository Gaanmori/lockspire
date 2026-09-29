// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Gabriel Ángel Montoya Rico

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:lockspire/features/sync/domain/vault_merge.dart';
import 'package:lockspire/features/vault/domain/entities/vault.dart';
import 'package:lockspire/features/vault/domain/entities/vault_entry.dart';
import 'package:lockspire/features/vault/domain/ports/site_icon_fetcher_port.dart';
import 'package:lockspire/features/vault/domain/site_icons.dart';
import 'package:lockspire/features/vault/infrastructure/http_site_icon_fetcher.dart';

VaultEntry _entry(String title, [String? url]) =>
    VaultEntry.create(title: title, fields: {'password': 'p', 'url': ?url});

void main() {
  group('HttpSiteIconFetcher', () {
    test('lee los íconos declarados: apple-touch-icon primero, sin SVG ni '
        'http', () {
      final page = Uri.parse('https://sitio.test/inicio/');
      final urls = iconCandidates(page, '''
<head>
  <link rel="icon" href="/favicon-16.png" sizes="16x16">
  <link rel="icon" type="image/svg+xml" href="/logo.svg">
  <link href="icons/touch.png" rel="apple-touch-icon">
  <link rel='shortcut icon' href='http://sitio.test/viejo.ico'>
  <link rel="icon" href="https://cdn.sitio.test/i-64.png" sizes="64x64">
  <link rel="stylesheet" href="/estilos.css">
</head>''');
      expect(urls.map((u) => u.toString()), [
        'https://sitio.test/inicio/icons/touch.png',
        'https://cdn.sitio.test/i-64.png',
        'https://sitio.test/favicon-16.png',
      ]);
    });

    test('nunca sigue una redirección a http', () async {
      final requested = <Uri>[];
      final client = MockClient((request) async {
        requested.add(request.url);
        return http.Response(
          '',
          301,
          headers: {'location': 'http://sitio.test/'},
        );
      });
      final png = await HttpSiteIconFetcher(
        client: client,
      ).fetchPng('sitio.test');
      expect(png, isNull);
      expect(requested.every((u) => u.scheme == 'https'), isTrue);
    });

    test('sin conexión avisa para reintentar luego', () async {
      final client = MockClient(
        (_) async => throw const SocketException('Failed host lookup'),
      );
      await expectLater(
        HttpSiteIconFetcher(client: client).fetchPng('sitio.test'),
        throwsA(isA<SiteIconOfflineException>()),
      );
    });

    test('un error inesperado es "sin ícono", nunca una excepción', () async {
      final client = MockClient((_) async => throw StateError('raro'));
      expect(
        await HttpSiteIconFetcher(client: client).fetchPng('sitio.test'),
        isNull,
      );
    });
  });

  group('Respaldo con DuckDuckGo (ADR 0030)', () {
    test('solo van los dominios donde el sitio no ofreció ícono', () {
      final vault = Vault(
        vaultId: 'v',
        schemaVersion: 1,
        entries: [
          _entry('A', 'https://a.test'),
          _entry('B', 'https://b.test'),
          _entry('C', 'https://c.test'),
          _entry('D', 'https://d.test'),
        ],
        siteIcons: const {'a.test': 'QUJD', 'b.test': '', 'c.test': '-'},
      );
      expect(hostsForIconFallback(vault), {'b.test'});
    });

    test('pide a icons.duckduckgo.com con solo el dominio', () async {
      final requested = <Uri>[];
      final client = MockClient((request) async {
        requested.add(request.url);
        return http.Response('', 404);
      });
      expect(
        await HttpSiteIconFetcher.duckDuckGo(client: client).fetchPng('b.test'),
        isNull,
      );
      expect(
        requested.single.toString(),
        'https://icons.duckduckgo.com/ip3/b.test.ico',
      );
    });

    test('"sin ícono en ningún lado" no le gana a un ícono en el merge, y '
        'volver a buscar lo olvida', () {
      final base = Vault(vaultId: 'v', schemaVersion: 1);
      final merged = mergeVaults(
        ancestor: base,
        local: base.withSiteIcons({'a.test': '-'}),
        remote: base.withSiteIcons({'a.test': 'QQ=='}),
      ).autoMerged;
      expect(merged.siteIcons['a.test'], 'QQ==');
      expect(
        base
            .withSiteIcons({'x.test': '-', 'y.test': ''})
            .withoutMissingSiteIcons()
            .siteIcons,
        isEmpty,
      );
      expect(isSiteIcon('-'), isFalse);
      expect(isSiteIcon(''), isFalse);
    });
  });
}
