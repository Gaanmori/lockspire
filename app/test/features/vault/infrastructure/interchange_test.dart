// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Gabriel Ángel Montoya Rico

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:lockspire/shared/domain/app_problem.dart';
import 'package:lockspire/features/vault/application/create_vault_use_case.dart';
import 'package:lockspire/features/vault/application/vault_transfer_use_cases.dart';
import 'package:lockspire/features/vault/domain/entities/entry_fields.dart';
import 'package:lockspire/features/vault/domain/entities/vault_entry.dart';
import 'package:lockspire/features/vault/domain/vault_file_codec.dart';
import 'package:lockspire/features/vault/domain/vault_import_merge.dart';
import 'package:lockspire/features/vault/infrastructure/interchange/bitwarden_json.dart';
import 'package:lockspire/features/vault/infrastructure/interchange/csv_codec.dart';
import 'package:lockspire/features/vault/infrastructure/interchange/csv_exporters.dart';
import 'package:lockspire/features/vault/infrastructure/interchange/csv_import_source.dart';

import '../application/fakes.dart';

/// Datos inventados. Nunca datos reales del usuario.
final _login = VaultEntry.create(
  title: 'Amazon',
  fields: {
    'username': 'persona@ejemplo.test',
    'password': 'clave, con "comillas"\ny salto',
    'url': 'https://amazon.test',
    'url_2': 'https://amazon.es.test',
    'app': 'com.amazon.test',
    'custom:Pregunta': 'perro',
    'hidden:PIN web': '1234',
    'notes': 'Nota\nde dos líneas',
  },
  fieldHistory: {
    'password': [
      FieldHistoryRecord(
        value: 'vieja',
        replacedAt: DateTime.utc(2025, 1, 2, 3, 4, 5),
      ),
    ],
  },
);

final _card = VaultEntry.create(
  title: 'Visa inventada',
  type: VaultEntryType.card,
  fields: {
    'card_number': '4111111111111111',
    'card_holder': 'Persona Inventada',
    'card_expiry': '08/29',
    'card_cvv': '123',
    'card_pin': '9999',
    'custom:Cancelación': '555-0100',
  },
);

final _document = VaultEntry.create(
  title: 'Cédula inventada',
  type: VaultEntryType.document,
  fields: {
    'doc_number': '123456789',
    'doc_name': 'Persona Inventada',
    'doc_birth_date': '01/01/1990',
    'doc_issued': '02/02/2010',
    'doc_expiry': '03/03/2030',
  },
);

/// Lo que importa comparar tras un ida y vuelta: tipo, título y campos,
/// en texto ordenado (un `Map` dentro de un record se compara por
/// identidad, no por contenido).
String _shape(VaultEntry e) => _shapeOf(e.type, e.title, e.fields);

String _shapeOf(VaultEntryType type, String title, Map<String, String> f) {
  final keys = f.keys.toList()..sort();
  return '${type.name}|$title|${[for (final k in keys) '$k=${f[k]}'].join('|')}';
}

void main() {
  group('CSV (RFC 4180)', () {
    test('ida y vuelta con comas, comillas, saltos de línea y espacios', () {
      final rows = [
        ['a', 'b,c', 'd "e"', 'f\ng', ' h '],
        ['', 'x', '', '', ''],
      ];
      expect(parseCsv(encodeCsv(rows)), rows);
    });

    test('BOM, \\r\\n y línea final vacía', () {
      expect(parseCsv('﻿name,url\r\nA,B\r\n\r\n'), [
        ['name', 'url'],
        ['A', 'B'],
      ]);
    });

    test('comillas sin cerrar es un error, no datos a medias', () {
      expect(
        () => parseCsv('a,"b\n'),
        throwsA(
          isA<AppProblem>().having(
            (e) => e.code,
            'code',
            AppProblemCode.importCsvUnclosedQuote,
          ),
        ),
      );
    });
  });

  group('JSON de Bitwarden', () {
    test('ida y vuelta exacto de contraseña, tarjeta y documento', () async {
      final json = BitwardenJsonExporter().encode([_login, _card, _document]);
      final back = await BitwardenJsonImportSource().parse(json);
      expect(back.map(_shape), [_login, _card, _document].map(_shape));
      expect(back.first.fieldHistory['password']!.single.value, 'vieja');
    });

    test('las apps viajan como androidapp:// y los ocultos como tipo 1', () {
      final json = jsonDecode(BitwardenJsonExporter().encode([_login])) as Map;
      final item = (json['items'] as List).single as Map;
      final uris = [
        for (final u in (item['login'] as Map)['uris'] as List)
          (u as Map)['uri'],
      ];
      expect(uris, contains('androidapp://com.amazon.test'));
      final pin = (item['fields'] as List).firstWhere(
        (f) => (f as Map)['name'] == 'PIN web',
      );
      expect((pin as Map)['type'], 1);
      expect(json['encrypted'], isFalse);
    });

    test('un JSON cifrado de Bitwarden se rechaza con instrucciones', () {
      expect(
        () => BitwardenJsonImportSource().parse(
          '{"encrypted": true, "items": []}',
        ),
        throwsA(
          isA<AppProblem>().having(
            (e) => e.code,
            'code',
            AppProblemCode.importBitwardenEncrypted,
          ),
        ),
      );
    });

    test(
      'identidad de Bitwarden → documento; TOTP como campo oculto',
      () async {
        final entries = await BitwardenJsonImportSource().parse(
          jsonEncode({
            'encrypted': false,
            'items': [
              {
                'type': 4,
                'name': 'Pasaporte',
                'identity': {
                  'firstName': 'Ana',
                  'lastName': 'Prueba',
                  'passportNumber': 'X123',
                  'email': 'ana@ejemplo.test',
                },
              },
              {
                'type': 1,
                'name': '',
                'login': {
                  'username': 'u',
                  'password': 'p',
                  'totp': 'JBSWY3DP',
                  'uris': [
                    {'uri': 'https://sitio.test/login'},
                  ],
                },
              },
            ],
          }),
        );
        final doc = entries.first;
        expect(doc.type, VaultEntryType.document);
        expect(doc.fields['doc_name'], 'Ana Prueba');
        expect(doc.fields['doc_number'], 'X123');
        expect(doc.fields['custom:Email'], 'ana@ejemplo.test');
        final login = entries.last;
        expect(login.title, 'sitio.test');
        expect(login.fields['hidden:TOTP'], 'JBSWY3DP');
      },
    );
  });

  group('CSV de Bitwarden', () {
    test('ida y vuelta: la contraseña con sus sitios, apps y campos; tarjeta '
        'y documento vuelven desde notas', () async {
      final csv = BitwardenCsvExporter().encode([_login, _card, _document]);
      final source = CsvImportSource();
      final back = await source.parse(csv);
      expect(source.detected, CsvSource.bitwarden);
      // El CSV no distingue campos ocultos: vuelven como visibles.
      String visible(VaultEntry e) => _shapeOf(e.type, e.title, {
        for (final MapEntry(:key, :value) in e.fields.entries)
          key.startsWith('hidden:') ? 'custom:${key.substring(7)}' : key: value,
      });
      expect(back.map(_shape), [_login, _card, _document].map(visible));
    });
  });

  group('CSV de Chrome, Firefox, KeePassXC y genérico', () {
    test(
      'Chrome: una fila por sitio al exportar, una entrada al importar',
      () async {
        final csv = ChromeCsvExporter().encode([_login, _card]);
        final rows = parseCsv(csv);
        expect(rows.first, ['name', 'url', 'username', 'password', 'note']);
        expect(rows.length, 3, reason: 'dos sitios; la tarjeta no va');

        final source = CsvImportSource();
        final back = await source.parse(csv);
        expect(source.detected, CsvSource.chrome);
        expect(back.single.urls, _login.urls);
        expect(back.single.fields['password'], _login.fields['password']);
      },
    );

    test('Firefox: sin título, usa el host', () async {
      final source = CsvImportSource();
      final back = await source.parse(
        'url,username,password,httpRealm,formActionOrigin,guid,timeCreated,'
        'timeLastUsed,timePasswordChanged\n'
        'https://www.sitio.test,u,p,,,{1},1,1,1\n',
      );
      expect(source.detected, CsvSource.firefox);
      expect(back.single.title, 'www.sitio.test');
    });

    test('KeePassXC', () async {
      final source = CsvImportSource();
      final back = await source.parse(
        '"Group","Title","Username","Password","URL","Notes","TOTP"\n'
        '"Raíz","Correo","u","p","https://correo.test","n","SECRETO"\n',
      );
      expect(source.detected, CsvSource.keepass);
      final e = back.single;
      expect(e.title, 'Correo');
      expect(e.fields['notes'], 'n');
      expect(e.fields['hidden:TOTP'], 'SECRETO');
    });

    test('sin columna de contraseña no es un CSV de contraseñas', () {
      expect(
        () => CsvImportSource().parse('a,b\n1,2\n'),
        throwsA(isA<AppProblem>()),
      );
    });
  });

  group('Importar nunca duplica (ADR 0027)', () {
    test('omite el mismo id, el mismo contenido y repetidos del archivo', () {
      final copy = VaultEntry.create(
        title: 'AMAZON ',
        fields: {
          'username': 'persona@ejemplo.test',
          'password': _login.fields['password']!,
        },
      );
      final nueva = VaultEntry.create(
        title: 'Nueva',
        fields: {'password': 'x'},
      );
      final selection = selectEntriesToImport(
        existing: [_login],
        incoming: [_login, copy, nueva, nueva],
      );
      expect(selection.toAdd, [nueva]);
      expect(selection.skipped, 3);
    });
  });

  group('Respaldo cifrado', () {
    test('se abre con la contraseña correcta y no con otra', () async {
      final crypto = FakeCryptoPort();
      final storage = FakeVaultStoragePort();
      final created = await CreateVaultUseCase(
        storage: storage,
        crypto: crypto,
      ).call(masterPassword: 'contraseña de prueba larga');

      final bytes = await encryptedBackupBytes(storage);
      expect(
        VaultFileCodec.decode(bytes).header.vaultId,
        created.header.vaultId,
      );

      final read = ReadEncryptedBackupUseCase(crypto: crypto);
      expect(
        await read.call(bytes: bytes, password: 'contraseña de prueba larga'),
        isEmpty,
      );
      await expectLater(
        read.call(bytes: bytes, password: 'otra'),
        throwsA(isA<IncorrectBackupPasswordException>()),
      );
    });

    test('verificar la contraseña maestra antes de exportar', () async {
      final crypto = FakeCryptoPort();
      final created = await CreateVaultUseCase(
        storage: FakeVaultStoragePort(),
        crypto: crypto,
      ).call(masterPassword: 'contraseña de prueba larga');
      final verify = VerifyMasterPasswordUseCase(crypto: crypto);
      expect(
        await verify.call(
          password: 'contraseña de prueba larga',
          header: created.header,
          sessionKey: created.key,
        ),
        isTrue,
      );
      expect(
        await verify.call(
          password: 'otra',
          header: created.header,
          sessionKey: created.key,
        ),
        isFalse,
      );
    });

    test('un archivo que no es de Lockspire se rechaza', () async {
      await expectLater(
        ReadEncryptedBackupUseCase(
          crypto: FakeCryptoPort(),
        ).call(bytes: utf8.encode('no soy una bóveda'), password: 'x'),
        throwsA(isA<AppProblem>()),
      );
    });
  });

  test('las keys de apps y sitios se conservan como EntryFields', () {
    expect(_login.apps, ['com.amazon.test']);
    expect(EntryFields.url, 'url');
  });
}
