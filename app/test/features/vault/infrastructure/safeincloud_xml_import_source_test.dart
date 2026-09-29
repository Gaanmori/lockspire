// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Gabriel Ángel Montoya Rico

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lockspire/features/vault/domain/entities/entry_fields.dart';
import 'package:lockspire/features/vault/domain/entities/vault_entry.dart';
import 'package:lockspire/features/vault/infrastructure/safeincloud_xml_import_source.dart';

/// XML sintético con datos inventados. Nunca un archivo real del usuario.
/// Imita la estructura del export de SafeInCloud documentada en
/// docs/STATE.md: plantillas, papelera, etiquetas, `ghost`, `record`,
/// historial en JSON, `autofill` y varios sitios y apps por tarjeta.
const _fixtureXml = '''
<?xml version="1.0" encoding="utf-8"?>
<database>
  <ghost id="2" first_stamp="1700000000000" time_stamp="1700000000000" />
  <card title="Tarjeta de crédito" id="101" symbol="credit_card" template="true" autofill="on">
    <field name="Número" type="number" autofill="cc-number" />
  </card>
  <label name="Web Accounts" type="web_accounts" id="900" />
  <card title="Ejemplo Web" id="1" symbol="web_site" autofill="on" first_stamp="1669000000000" time_stamp="1669000000001">
    <field name="Usuario" type="login" autofill="username" history="{&quot;1669000000000&quot;:&quot;&quot;,&quot;1669100000000&quot;:&quot;viejo@ejemplo.test&quot;}">usuario@ejemplo.test</field>
    <field name="Contraseña" type="password" autofill="current-password" score="4" hash="00000000000000000000000000000000" history="{&#xD;&#xA;  &quot;1600000000000&quot;: &quot;clave-1&quot;,&#xD;&#xA;  &quot;1610000000000&quot;: &quot;clave-2&quot;,&#xD;&#xA;  &quot;1620000000000&quot;: &quot;clave-3&quot;,&#xD;&#xA;  &quot;1630000000000&quot;: &quot;clave-4&quot;&#xD;&#xA;}">clave-actual</field>
    <field name="Dirección web" type="website" autofill="url">https://ejemplo.test/login</field>
    <field name="Contraseña temporal (2FA)" type="one_time_password" autofill="one-time-code" />
    <label_id>900</label_id>
    <field name="Dirección web" type="website" autofill="url" />
    <field name="Website" type="website" autofill="url">https://cuenta.ejemplo.test</field>
    <field name="Aplicación" type="application" autofill="url">com.ejemplo.app</field>
    <field name="Aplicación" type="application" autofill="url">com.ejemplo.app.beta</field>
    <field name="PIN" type="pin" autofill="off">4321</field>
    <field name="Pregunta secreta" type="text" autofill="off">Primer perro</field>
    <notes>Nota de la tarjeta.</notes>
  </card>
  <card title="Tarjeta inventada" id="2" symbol="credit_card" type="card" autofill="on">
    <field name="Número" type="number" autofill="cc-number">4111111111111111</field>
    <field name="Titular" type="text" autofill="cc-name">Persona Inventada</field>
    <field name="Vence" type="expiry" autofill="cc-exp" score="1" hash="x">12/30</field>
    <field name="CVV" type="pin" autofill="cc-csc">123</field>
    <field name="PIN" type="pin" autofill="off">9999</field>
    <field name="Cancelación" type="phone" autofill="off">555-0100</field>
  </card>
  <card title="Cédula inventada" id="3" symbol="id" autofill="off">
    <field name="Número" type="text" autofill="off">123456789</field>
    <field name="Nombre" type="text" autofill="off">Persona Inventada</field>
    <field name="Fecha de nacimiento" type="date" autofill="off">01/01/1990</field>
    <field name="Expedido" type="date" autofill="off">02/02/2010</field>
    <field name="Vence" type="expiry" autofill="off">03/03/2030</field>
  </card>
  <card title="" id="4" autofill="on">
    <field name="Usuario" type="login" autofill="username">sin-titulo</field>
  </card>
  <card title="Borrada" id="5" deleted="true">
    <field name="Usuario" type="login">no-debe-importarse</field>
  </card>
  <card title="Borrada vieja" id="6" deleted="1">
    <field name="Usuario" type="login">tampoco-debe-importarse</field>
  </card>
  <record id="999" first_stamp="1" time_stamp="1">["no-importar"]</record>
</database>
''';

void main() {
  group('SafeInCloudXmlImportSource (ADR 0025)', () {
    late SafeInCloudXmlImportSource source;
    late List<VaultEntry> entries;

    VaultEntry byTitle(String title) =>
        entries.firstWhere((e) => e.title == title);

    setUp(() async {
      source = SafeInCloudXmlImportSource();
      entries = await source.parse(_fixtureXml);
    });

    test('importa solo las tarjetas vivas: sin papelera, plantillas ni '
        'record', () {
      expect(entries, hasLength(4));
      final all = entries.expand((e) => e.fields.values).join(' ');
      expect(all, isNot(contains('no-debe-importarse')));
      expect(all, isNot(contains('tampoco-debe-importarse')));
      expect(all, isNot(contains('no-importar')));
    });

    test('contraseña: usuario, contraseña, todos los sitios y todas las '
        'apps, cada uno en su campo', () {
      final entry = byTitle('Ejemplo Web');
      expect(entry.type, VaultEntryType.password);
      expect(entry.fields[EntryFields.username], 'usuario@ejemplo.test');
      expect(entry.fields[EntryFields.password], 'clave-actual');
      expect(entry.urls, [
        'https://ejemplo.test/login',
        'https://cuenta.ejemplo.test',
      ]);
      expect(entry.apps, ['com.ejemplo.app', 'com.ejemplo.app.beta']);
    });

    test('los demás campos conservan su nombre; PIN oculto; notas de la '
        'tarjeta; nada a notas como línea transicional', () {
      final entry = byTitle('Ejemplo Web');
      final custom = {for (final f in entry.customFields) f.name: f};
      expect(custom['Pregunta secreta']?.value, 'Primer perro');
      expect(custom['Pregunta secreta']?.hidden, isFalse);
      expect(custom['PIN']?.value, '4321');
      expect(custom['PIN']?.hidden, isTrue);
      expect(entry.fields[EntryFields.notes], 'Nota de la tarjeta.');
      expect(
        entry.fields[EntryFields.notes],
        isNot(contains(transitionalPrefix)),
      );
      // TOTP vacío y sitio vacío no generan nada.
      expect(
        entry.fields.keys,
        isNot(contains(startsWith('hidden:Contraseña temporal'))),
      );
    });

    test('historial: valores anteriores no vacíos, del más reciente al más '
        'viejo, hasta el tope; score y hash no se importan', () {
      final entry = byTitle('Ejemplo Web');
      final passwords = entry.fieldHistory[EntryFields.password]!;
      expect(passwords.map((r) => r.value), ['clave-4', 'clave-3', 'clave-2']);
      expect(
        passwords.first.replacedAt,
        DateTime.fromMillisecondsSinceEpoch(1630000000000, isUtc: true),
      );
      expect(entry.fieldHistory[EntryFields.username]!.map((r) => r.value), [
        'viejo@ejemplo.test',
      ]);
      final all = entry.fields.values.join(' ');
      expect(all, isNot(contains('00000000000000000000000000000000')));
    });

    test('tarjeta: número, titular, vence, CVV y PIN en sus campos; el '
        'teléfono de cancelación como campo con nombre', () {
      final entry = byTitle('Tarjeta inventada');
      expect(entry.type, VaultEntryType.card);
      expect(entry.fields[EntryFields.cardNumber], '4111111111111111');
      expect(entry.fields[EntryFields.cardHolder], 'Persona Inventada');
      expect(entry.fields[EntryFields.cardExpiry], '12/30');
      expect(entry.fields[EntryFields.cardCvv], '123');
      expect(entry.fields[EntryFields.cardPin], '9999');
      expect(entry.fields['custom:Cancelación'], '555-0100');
    });

    test('documento: número, nombre y fechas en sus campos', () {
      final entry = byTitle('Cédula inventada');
      expect(entry.type, VaultEntryType.document);
      expect(entry.fields[EntryFields.docNumber], '123456789');
      expect(entry.fields[EntryFields.docName], 'Persona Inventada');
      expect(entry.fields[EntryFields.docBirthDate], '01/01/1990');
      expect(entry.fields[EntryFields.docIssued], '02/02/2010');
      expect(entry.fields[EntryFields.docExpiry], '03/03/2030');
      expect(entry.customFields, isEmpty);
    });

    test('campos repetidos no se pisan: la segunda contraseña y el segundo '
        'usuario quedan con su nombre', () async {
      final parsed = await source.parse('''
<database>
  <card title="Dos de todo">
    <field name="Usuario" type="login">principal</field>
    <field name="Correo" type="login">otro@ejemplo.test</field>
    <field name="Contraseña" type="password">primera</field>
    <field name="Clave web" type="password">segunda</field>
    <field name="Clave web" type="password">tercera</field>
  </card>
</database>
''');
      final entry = parsed.single;
      expect(entry.fields[EntryFields.username], 'principal');
      expect(entry.fields[EntryFields.password], 'primera');
      expect(entry.fields['custom:Correo'], 'otro@ejemplo.test');
      expect(entry.fields['hidden:Clave web'], 'segunda');
      expect(entry.fields['hidden:Clave web (2)'], 'tercera');
    });

    test('título vacío cae a un placeholder visible', () {
      final entry = entries.firstWhere(
        (e) => e.fields[EntryFields.username] == 'sin-titulo',
      );
      expect(entry.title, 'Sin título');
    });

    test('un payload XXE (DOCTYPE + ENTITY apuntando a un archivo local real) '
        'no filtra el contenido de ese archivo al valor parseado', () async {
      final tempDir = await Directory.systemTemp.createTemp('lockspire_xxe_');
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
        final parsed = await source.parse(xxeXml);
        for (final entry in parsed) {
          for (final value in entry.fields.values) {
            expect(value, isNot(contains(marker)));
          }
        }
      } on FormatException {
        // Rechazar el documento de plano también es un resultado seguro.
      } finally {
        await tempDir.delete(recursive: true);
      }
    });
  });
}
