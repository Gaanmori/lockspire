// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Lockspire

import 'package:flutter_test/flutter_test.dart';
import 'package:lockspire/features/sync/domain/webdav_url_policy.dart';

void main() {
  group('checkWebDavUrl (S7)', () {
    test('acepta https hacia cualquier servidor', () {
      expect(checkWebDavUrl('https://nube.ejemplo/dav'), isNull);
      expect(checkWebDavUrl('HTTPS://192.168.1.10:8443/remote.php'), isNull);
      expect(checkWebDavUrl('  https://nube.ejemplo/dav  '), isNull);
    });

    test('acepta http solo hacia este mismo equipo', () {
      expect(checkWebDavUrl('http://localhost:8080/dav'), isNull);
      expect(checkWebDavUrl('http://127.0.0.1/dav'), isNull);
      expect(checkWebDavUrl('http://[::1]:8080/dav'), isNull);
      expect(checkWebDavUrl('http://LOCALHOST/dav'), isNull);
    });

    test('rechaza http hacia otros equipos', () {
      for (final url in [
        'http://nube.ejemplo/dav',
        'http://192.168.1.10/dav',
        'http://localhost.atacante.ejemplo/dav',
        'http://127.0.0.1.nip.io/dav',
      ]) {
        expect(checkWebDavUrl(url), WebDavUrlProblem.insecure, reason: url);
      }
    });

    test('rechaza URLs sin esquema http(s) o sin host', () {
      for (final url in [
        '',
        'nube.ejemplo/dav',
        'ftp://nube.ejemplo/dav',
        'file:///C:/boveda',
        'https://',
        'http://[mal',
      ]) {
        expect(checkWebDavUrl(url), WebDavUrlProblem.invalid, reason: url);
      }
    });
  });
}
