// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Lockspire

import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:lockspire/features/vault/application/create_vault_use_case.dart';
import 'package:lockspire/features/vault/application/prepare_import_use_case.dart';
import 'package:lockspire/features/vault/application/save_vault_use_case.dart';
import 'package:lockspire/features/vault/application/vault_transfer_use_cases.dart';
import 'package:lockspire/features/vault/domain/entities/vault_entry.dart';
import 'package:lockspire/features/vault/infrastructure/interchange/csv_import_source.dart';

import 'fakes.dart';

const _password = 'contraseña de prueba larga';

void main() {
  late FakeCryptoPort crypto;
  late PrepareImportUseCase prepare;

  setUp(() {
    crypto = FakeCryptoPort();
    prepare = PrepareImportUseCase(
      sourceFor: (ext) => ext == 'csv' ? CsvImportSource() : null,
      readBackup: ReadEncryptedBackupUseCase(crypto: crypto),
    );
  });

  Future<String?> noPassword() async => fail('no debería pedir contraseña');

  final csv = Uint8List.fromList(
    utf8.encode('name,url,username,password\nSitio,https://s.test,u,p\n'),
  );

  test('un CSV se lee sin pedir contraseña y se marca sin cifrar', () async {
    final prepared = await prepare.call(
      bytes: csv,
      fileName: 'export.CSV',
      existing: const [],
      askBackupPassword: noPassword,
    );
    expect(prepared!.sourceUnencrypted, isTrue);
    expect(prepared.selection.toAdd.single.title, 'Sitio');
  });

  test('lo que ya está en la bóveda se omite', () async {
    final existing = VaultEntry.create(
      title: 'Sitio',
      fields: {'username': 'u', 'password': 'p'},
    );
    final prepared = await prepare.call(
      bytes: csv,
      fileName: 'export.csv',
      existing: [existing],
      askBackupPassword: noPassword,
    );
    expect(prepared!.selection.toAdd, isEmpty);
    expect(prepared.selection.skipped, 1);
  });

  test('una extensión desconocida se rechaza con un mensaje claro', () async {
    await expectLater(
      prepare.call(
        bytes: csv,
        fileName: 'notas.txt',
        existing: const [],
        askBackupPassword: noPassword,
      ),
      throwsA(
        isA<UnknownImportFormatException>().having(
          (e) => '$e',
          'mensaje',
          contains('.txt'),
        ),
      ),
    );
  });

  group('respaldo .lockspire', () {
    Future<Uint8List> backupWithOneEntry() async {
      final storage = FakeVaultStoragePort();
      final created = await CreateVaultUseCase(
        storage: storage,
        crypto: crypto,
      ).call(masterPassword: _password);
      await SaveVaultUseCase(storage: storage, crypto: crypto).call(
        vault: created.vault.withEntryAdded(
          VaultEntry.create(title: 'Del respaldo', fields: {'password': 'x'}),
        ),
        key: created.key,
        header: created.header,
        expectedFileHash: created.fileHash,
      );
      return encryptedBackupBytes(storage);
    }

    test(
      'pide la contraseña y trae sus entradas, marcado como cifrado',
      () async {
        final prepared = await prepare.call(
          bytes: await backupWithOneEntry(),
          fileName: 'lockspire-2026-09-28.lockspire',
          existing: const [],
          askBackupPassword: () async => _password,
        );
        expect(prepared!.sourceUnencrypted, isFalse);
        expect(prepared.selection.toAdd.single.title, 'Del respaldo');
      },
    );

    test('cancelar la contraseña no importa nada', () async {
      expect(
        await prepare.call(
          bytes: await backupWithOneEntry(),
          fileName: 'r.lockspire',
          existing: const [],
          askBackupPassword: () async => null,
        ),
        isNull,
      );
    });

    test('con otra contraseña no se abre', () async {
      await expectLater(
        prepare.call(
          bytes: await backupWithOneEntry(),
          fileName: 'r.lockspire',
          existing: const [],
          askBackupPassword: () async => 'otra',
        ),
        throwsA(isA<IncorrectBackupPasswordException>()),
      );
    });
  });
}
