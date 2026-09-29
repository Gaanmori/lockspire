// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Gabriel Ángel Montoya Rico

import 'package:flutter_test/flutter_test.dart';
import 'package:lockspire/features/sync/domain/vault_merge.dart';
import 'package:lockspire/features/vault/domain/entities/vault.dart';
import 'package:lockspire/features/vault/domain/entities/vault_entry.dart';
import 'package:lockspire/features/vault/domain/site_icons.dart';

VaultEntry _entry(String title, [String? url]) =>
    VaultEntry.create(title: title, fields: {'password': 'p', 'url': ?url});

void main() {
  group('Dominio (ADR 0029)', () {
    test('el sitio del ícono es el host del primer sitio, sin www', () {
      expect(
        iconHostOf(_entry('a', 'https://WWW.Amazon.com/login')),
        'amazon.com',
      );
      expect(iconHostOf(_entry('a', 'github.com')), 'github.com');
      expect(iconHostOf(_entry('a')), isNull);
    });

    test('nunca se consultan direcciones locales ni IPs', () {
      for (final host in [
        'localhost',
        '192.168.1.1',
        'router',
        'nas.local',
        'casa.lan',
        'app.localhost',
        'svc.internal',
        '[::1]',
      ]) {
        expect(isFetchableIconHost(host), isFalse, reason: host);
      }
      expect(isFetchableIconHost('icetex.gov.co'), isTrue);
    });

    test('faltan los sitios públicos sin ícono ni búsqueda previa', () {
      final vault = Vault(
        vaultId: 'v',
        schemaVersion: 1,
        entries: [
          _entry('A', 'https://a.test'),
          _entry('B', 'https://b.test'),
          _entry('Router', 'http://192.168.1.1'),
          _entry('C', 'https://c.test').copyWith(deleted: true),
        ],
        siteIcons: const {'b.test': ''},
      );
      expect(hostsMissingIcons(vault), {'a.test'});
    });

    test('la letra es el primer carácter útil del título', () {
      expect(entryInitial(_entry('::.SM4 Web.::')), 'S');
      expect(entryInitial(_entry('4-72')), '4');
      expect(entryInitial(_entry('ñandú')), 'Ñ');
      expect(entryInitial(_entry('...', 'https://www.zeta.test')), 'Z');
    });

    test(
      'los íconos viajan en el JSON y "volver a buscar" olvida los vacíos',
      () {
        final vault = Vault(
          vaultId: 'v',
          schemaVersion: 1,
        ).withSiteIcons({'a.test': 'QUJD', 'b.test': ''});
        final back = Vault.fromJson(vault.toJson());
        expect(back.siteIcons, {'a.test': 'QUJD', 'b.test': ''});
        expect(back.withoutMissingSiteIcons().siteIcons, {'a.test': 'QUJD'});
      },
    );

    test('el merge une los íconos; uno encontrado le gana a "sin ícono"', () {
      final base = Vault(vaultId: 'v', schemaVersion: 1);
      final local = base.withSiteIcons({'a.test': '', 'c.test': 'Qw=='});
      final remote = base.withSiteIcons({'a.test': 'QQ==', 'b.test': 'Qg=='});
      final merged = mergeVaults(
        ancestor: base,
        local: local,
        remote: remote,
      ).autoMerged;
      expect(merged.siteIcons, {
        'a.test': 'QQ==',
        'b.test': 'Qg==',
        'c.test': 'Qw==',
      });
    });
  });
}
