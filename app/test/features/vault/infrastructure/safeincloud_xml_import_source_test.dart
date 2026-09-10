// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Lockspire

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lockspire/features/vault/infrastructure/safeincloud_xml_import_source.dart';

/// XML sintético e inventado — nunca el archivo real del usuario (se borró
/// y no debe volver a existir en el repo, ver docs/STATE.md — Fase 6).
/// Cubre al menos un campo de cada `type` real confirmado contra ese
/// export: login, password, website, text, one_time_password, pin,
/// number, date, expiry, application.
const _fixtureXml = '''
<?xml version="1.0" encoding="UTF-8"?>
<database>
  <card id="1" title="Ejemplo Login" type="0" deleted="0" template="0">
    <field name="Usuario" type="login">usuario.ejemplo</field>
    <field name="Contraseña" type="password">correcto-caballo-batería</field>
    <field name="Sitio" type="website">https://ejemplo.test</field>
    <field name="Notas" type="text">Primera nota libre.</field>
    <field name="Más notas" type="text">Segunda nota libre.</field>
  </card>
  <card id="2" title="Ejemplo TOTP y tarjeta" type="0">
    <field name="Código de verificación" type="one_time_password">JBSWY3DPEHPK3PXP</field>
    <field name="PIN" type="pin">1234</field>
    <field name="Número" type="number">4111 1111 1111 1111</field>
    <field name="Fecha" type="date">2020-01-01</field>
    <field name="Vencimiento" type="expiry">12/28</field>
    <field name="Aplicación" type="application">com.ejemplo.app</field>
  </card>
  <card id="3" title="" type="0">
    <field name="Usuario" type="login">sin-titulo</field>
  </card>
  <card id="4" title="Borrada" deleted="1">
    <field name="Usuario" type="login">no-debe-importarse</field>
  </card>
  <card id="5" title="Plantilla" template="1">
    <field name="Usuario" type="login">tampoco-debe-importarse</field>
  </card>
</database>
''';

void main() {
  group('SafeInCloudXmlImportSource', () {
    late SafeInCloudXmlImportSource source;

    setUp(() {
      source = SafeInCloudXmlImportSource();
    });

    test(
      'login/password/website mapean a los fields correctos, texto libre '
      'se agrega a notes sin prefijo, sin pisarse entre sí',
      () async {
        final entries = await source.parse(_fixtureXml);
        final entry = entries.firstWhere((e) => e.title == 'Ejemplo Login');

        expect(entry.fields['username'], 'usuario.ejemplo');
        expect(entry.fields['password'], 'correcto-caballo-batería');
        expect(entry.fields['url'], 'https://ejemplo.test');
        expect(entry.fields['notes'], contains('Primera nota libre.'));
        expect(entry.fields['notes'], contains('Segunda nota libre.'));
        expect(entry.fields['notes'], isNot(contains('[$transitionalPrefix')));
      },
    );

    test(
      'campos no soportados (TOTP, PIN, tarjeta) quedan en notes con el '
      'prefijo transicional, parseable de vuelta con transitionalLineRegExp',
      () async {
        final entries = await source.parse(_fixtureXml);
        final entry = entries.firstWhere(
          (e) => e.title == 'Ejemplo TOTP y tarjeta',
        );
        final notes = entry.fields['notes'] ?? '';
        final lines = notes.split('\n');

        for (final expectedType in [
          'one_time_password',
          'pin',
          'number',
          'date',
          'expiry',
          'application',
        ]) {
          final line = lines.firstWhere(
            (l) => transitionalLineRegExp.firstMatch(l)?.group(1) ==
                expectedType,
            orElse: () => '',
          );
          expect(
            line,
            isNotEmpty,
            reason: 'No se encontró línea transicional para $expectedType',
          );
        }

        final otpLine = lines.firstWhere(
          (l) =>
              transitionalLineRegExp.firstMatch(l)?.group(1) ==
              'one_time_password',
        );
        final match = transitionalLineRegExp.firstMatch(otpLine)!;
        expect(match.group(2), 'Código de verificación');
        expect(match.group(3), 'JBSWY3DPEHPK3PXP');
      },
    );

    test('título vacío cae a un placeholder visible', () async {
      final entries = await source.parse(_fixtureXml);
      final entry = entries.firstWhere(
        (e) => e.fields['username'] == 'sin-titulo',
      );

      expect(entry.title, isNotEmpty);
    });

    test('cards deleted="1" y template="1" quedan excluidas', () async {
      final entries = await source.parse(_fixtureXml);

      expect(
        entries.any((e) => e.fields['username'] == 'no-debe-importarse'),
        isFalse,
      );
      expect(
        entries.any(
          (e) => e.fields['username'] == 'tampoco-debe-importarse',
        ),
        isFalse,
      );
    });

    test('importa exactamente las cards válidas del fixture (3)', () async {
      final entries = await source.parse(_fixtureXml);
      expect(entries, hasLength(3));
    });

    test(
      'un payload XXE (DOCTYPE + ENTITY apuntando a un archivo local real) '
      'no filtra el contenido de ese archivo al valor parseado',
      () async {
        final tempDir = await Directory.systemTemp.createTemp(
          'lockspire_xxe_',
        );
        final secretFile = File('${tempDir.path}/secreto.txt');
        const marker = 'CONTENIDO-SECRETO-QUE-NO-DEBE-FILTRARSE';
        await secretFile.writeAsString(marker);

        final secretUri = secretFile.uri.toString();
        final xxeXml =
            '''
<?xml version="1.0"?>
<!DOCTYPE database [
  <!ENTITY xxe SYSTEM "$secretUri">
]>
<database>
  <card id="1" title="XXE">
    <field name="Usuario" type="login">&xxe;</field>
  </card>
</database>
''';

        try {
          final entries = await source.parse(xxeXml);
          for (final entry in entries) {
            for (final value in entry.fields.values) {
              expect(value, isNot(contains(marker)));
            }
          }
        } on FormatException {
          // Rechazar el documento de plano también es un resultado seguro.
        } finally {
          await tempDir.delete(recursive: true);
        }
      },
    );
  });
}
