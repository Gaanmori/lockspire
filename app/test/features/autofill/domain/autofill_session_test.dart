// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Gabriel Ángel Montoya Rico

import 'package:flutter_test/flutter_test.dart';
import 'package:lockspire/features/autofill/domain/autofill_session.dart';
import 'package:lockspire/features/browser_bridge/domain/origin_matcher.dart';
import 'package:lockspire/features/vault/domain/entities/vault_entry.dart';

VaultEntry _entry(
  String title,
  Map<String, String> fields, {
  VaultEntryType type = VaultEntryType.password,
}) => VaultEntry.create(title: title, type: type, fields: fields);

void main() {
  group('Índice de la sesión de autofill (ADR 0026)', () {
    test('solo contraseñas con contraseña y algo con qué coincidir', () {
      final items = autofillSessionItems([
        _entry('Con sitio', {'password': 'p', 'url': 'https://a.test'}),
        _entry('Con app', {'password': 'p', 'app': 'com.a'}),
        _entry('Sin sitio ni app', {'password': 'p'}),
        _entry('Sin contraseña', {'url': 'https://b.test'}),
        _entry('Tarjeta', {
          'password': 'p',
          'url': 'https://c.test',
        }, type: VaultEntryType.card),
        _entry('Borrada', {
          'password': 'p',
          'url': 'https://d.test',
        }).copyWith(deleted: true),
      ]);
      expect(items.map((i) => i.title), ['Con sitio', 'Con app']);
    });

    test('los sitios se reducen a host + https, sin los que fijan puerto', () {
      final item = autofillSessionItems([
        _entry('x', {
          'password': 'p',
          'url': 'https://WWW.Ejemplo.test/login',
          'url_2': 'http://viejo.test',
          'url_3': 'sinesquema.test',
          'url_4': 'https://interno.test:8443',
        }),
      ]).single;
      expect(item.sites.map((s) => s.host), [
        'www.ejemplo.test',
        'viejo.test',
        'sinesquema.test',
      ]);
      expect(item.sites.map((s) => s.httpsOnly), [true, false, true]);
    });

    test('un sitio que no es web no entra', () {
      expect(storedSiteForNativeAutofill('ftp://a.test'), isNull);
      expect(storedSiteForNativeAutofill('   '), isNull);
    });
  });
}
