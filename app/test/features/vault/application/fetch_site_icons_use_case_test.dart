// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Gabriel Ángel Montoya Rico

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:lockspire/features/vault/application/fetch_site_icons_use_case.dart';
import 'package:lockspire/features/vault/domain/ports/site_icon_fetcher_port.dart';

class _FakeFetcher implements SiteIconFetcherPort {
  final Map<String, Object?> results;
  final asked = <String>[];

  _FakeFetcher(this.results);

  @override
  Future<Uint8List?> fetchPng(String host) async {
    asked.add(host);
    final r = results[host];
    if (r is Exception) throw r;
    return r as Uint8List?;
  }
}

void main() {
  group('FetchSiteIconsUseCase', () {
    test(
      'ícono → base64, sin ícono o error → vacío, sin red → se reintenta',
      () async {
        final fetcher = _FakeFetcher({
          'si.test': Uint8List.fromList([1, 2, 3]),
          'no.test': null,
          'roto.test': Exception('500'),
          'offline.test': const SiteIconOfflineException(),
        });
        final found = await FetchSiteIconsUseCase(
          fetcher: fetcher,
        ).call(['si.test', 'no.test', 'roto.test', 'offline.test']);
        expect(found, {'si.test': 'AQID', 'no.test': '', 'roto.test': ''});
        expect(fetcher.asked, hasLength(4));
      },
    );
  });
}
