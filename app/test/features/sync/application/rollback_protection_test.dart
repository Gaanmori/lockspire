// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Lockspire

import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:lockspire/features/sync/application/adopt_remote_master_password_use_case.dart';
import 'package:lockspire/features/sync/application/sync_master_password_change_replica.dart';
import 'package:lockspire/features/sync/application/sync_vault_use_case.dart';
import 'package:lockspire/features/vault/application/change_master_password_use_case.dart';
import 'package:lockspire/features/vault/application/create_vault_use_case.dart';
import 'package:lockspire/features/vault/application/save_vault_use_case.dart';
import 'package:lockspire/features/vault/application/unlock_vault_use_case.dart';
import 'package:lockspire/features/vault/application/unlocked_vault_result.dart';
import 'package:lockspire/features/vault/domain/entities/vault_entry.dart';
import 'package:lockspire/features/vault/domain/ports/vault_storage_port.dart';
import 'package:lockspire/features/vault/domain/vault_file_codec.dart';

import '../../vault/application/fakes.dart';
import 'fakes.dart';

const _password = 'contraseña de prueba larga';
const _newPassword = 'Tr3s-Tigres!Trigo nuevo';

VaultEntry _entry(String id, String title) => VaultEntry(
  id: id,
  type: VaultEntryType.password,
  title: title,
  createdAt: DateTime.utc(2026, 1, 1),
  modifiedAt: DateTime.utc(2026, 1, 1),
  fields: const {},
);

/// Un dispositivo: su bóveda local, su ancestro y su estado de sync.
class _Device {
  final local = FakeVaultStoragePort();
  final ancestor = FakeVaultStoragePort();
  final syncState = FakeSyncStatePort();
  final FakeCryptoPort crypto;
  final FakeSyncPort remote;
  late UnlockedVaultResult session;

  _Device(this.crypto, this.remote);

  SyncVaultUseCase _sync() => SyncVaultUseCase(
    localStorage: local,
    ancestorStorage: ancestor,
    remote: remote,
    syncState: syncState,
    crypto: crypto,
    key: session.key,
    header: session.header,
  );

  Future<SyncResult> sync() async {
    final result = await _sync().call();
    await _reload();
    return result;
  }

  Future<SyncResult> replaceRemoteWithLocal() =>
      _sync().replaceRemoteWithLocal();

  Future<void> addEntry(String id) async {
    await SaveVaultUseCase(storage: local, crypto: crypto).call(
      vault: session.vault.copyWith(
        entries: [...session.vault.entries, _entry(id, id)],
      ),
      key: session.key,
      header: session.header,
      expectedFileHash: session.fileHash,
    );
    await _reload();
  }

  Future<void> _reload() async {
    session = await UnlockVaultUseCase(
      storage: local,
      crypto: crypto,
    ).reloadWithKey(key: session.key);
  }

  Set<String> get titles => session.vault.entries.map((e) => e.title).toSet();
}

void main() {
  late FakeCryptoPort crypto;
  late FakeSyncPort remote;

  setUp(() {
    crypto = FakeCryptoPort();
    remote = FakeSyncPort();
  });

  Future<_Device> newDevice() async {
    final device = _Device(crypto, remote);
    device.session = await CreateVaultUseCase(
      storage: device.local,
      crypto: crypto,
    ).call(masterPassword: _password);
    return device;
  }

  /// Segundo dispositivo que restaura la bóveda de la nube.
  Future<_Device> restoredDevice() async {
    final device = _Device(crypto, remote);
    device.local.stored = remote.remoteFile;
    device.session = await UnlockVaultUseCase(
      storage: device.local,
      crypto: crypto,
    ).call(masterPassword: _password);
    await device.sync();
    return device;
  }

  Matcher rejectedAs(RemoteVaultRejection reason) => throwsA(
    isA<RemoteVaultRejectedException>().having(
      (e) => e.reason,
      'reason',
      reason,
    ),
  );

  group('Revisión en el archivo (ADR 0019)', () {
    test('una bóveda nueva nace en formato v2, revisión 1, y cada guardado '
        'la sube', () async {
      final a = await newDevice();
      expect(a.local.stored!.header.formatVersion, revisionFormatVersion);
      expect(a.local.stored!.header.revision, 1);

      await a.addEntry('e1');
      await a.addEntry('e2');
      expect(a.local.stored!.header.revision, 3);
    });

    test(
      'la revisión sale del archivo en disco, no de una sesión vieja',
      () async {
        final a = await newDevice();
        await a.addEntry('e1'); // disco: revisión 2
        final staleHeader = a.session.header.copyWith(revision: 1);

        await SaveVaultUseCase(storage: a.local, crypto: crypto).call(
          vault: a.session.vault,
          key: a.session.key,
          header: staleHeader,
          expectedFileHash: a.session.fileHash,
        );
        expect(a.local.stored!.header.revision, 3);
      },
    );

    test('un archivo v1 (sin revisión) se lee como revisión 0 y su AAD no '
        'cambia', () {
      final legacy = VaultHeader(
        formatVersion: 1,
        formatMinReaderVersion: 1,
        salt: Uint8List(16),
        nonce: Uint8List(24),
        vaultId: 'v',
        createdAt: DateTime.utc(2026, 1, 1),
        kdfParams: defaultArgon2Params,
      );
      final aad = utf8.decode(legacy.toAadBytes());
      expect(aad, isNot(contains('revision')));

      final decoded = VaultFileCodec.decode(
        VaultFileCodec.encode(
          VaultFile(header: legacy, encryptedPayload: Uint8List(32)),
        ),
      );
      expect(decoded.header.revision, 0);
      expect(decoded.header.toAadBytes(), legacy.toAadBytes());
    });

    test('v2 conserva la revisión en el ida y vuelta', () {
      final header = VaultHeader(
        formatVersion: 2,
        formatMinReaderVersion: 2,
        salt: Uint8List(16),
        nonce: Uint8List(24),
        vaultId: 'v',
        createdAt: DateTime.utc(2026, 1, 1),
        kdfParams: defaultArgon2Params,
        revision: 42,
      );
      final decoded = VaultFileCodec.decode(
        VaultFileCodec.encode(
          VaultFile(header: header, encryptedPayload: Uint8List(32)),
        ),
      );
      expect(decoded.header.revision, 42);
    });
  });

  group('La sync rechaza una versión vieja de la nube (S2)', () {
    test('sin cambios locales: no descarga la copia vieja', () async {
      final a = await newDevice();
      await a.sync();
      final b = await restoredDevice();
      final oldCopy = remote.remoteFile!;

      await a.addEntry('nueva');
      await a.sync();
      await b.sync();
      expect(b.titles, {'nueva'});

      // Quien controla la nube vuelve a subir la copia vieja.
      remote.remoteFile = oldCopy;
      final bLocal = b.local.stored;
      await expectLater(b.sync(), rejectedAs(RemoteVaultRejection.rollback));
      expect(b.local.stored, same(bLocal));
      expect(b.titles, {'nueva'});
    });

    test('con cambios locales: no fusiona con la copia vieja', () async {
      final a = await newDevice();
      await a.addEntry('antes');
      await a.sync();
      final oldCopy = remote.remoteFile!;
      await a.addEntry('después');
      await a.sync();

      remote.remoteFile = oldCopy;
      await a.addEntry('local');
      final aLocal = a.local.stored;
      await expectLater(a.sync(), rejectedAs(RemoteVaultRejection.rollback));
      expect(a.local.stored, same(aLocal));
    });

    test('tampoco sirve para deshacer un cambio de contraseña maestra '
        '(cierra la consecuencia pendiente de ADR 0018)', () async {
      final a = await newDevice();
      await a.sync();
      final oldPasswordCopy = remote.remoteFile!;

      a.session = await ChangeMasterPasswordUseCase(
        storage: a.local,
        crypto: crypto,
        replica: SyncMasterPasswordChangeReplica(
          localStorage: a.local,
          ancestorStorage: a.ancestor,
          remote: remote,
          syncState: a.syncState,
          crypto: crypto,
        ),
      ).call(currentPassword: _password, newPassword: _newPassword);

      remote.remoteFile = oldPasswordCopy;
      // Es rollback, no "la contraseña se cambió en otro dispositivo": no
      // debe pedirle al usuario ninguna contraseña.
      await expectLater(a.sync(), rejectedAs(RemoteVaultRejection.rollback));

      final adopt = AdoptRemoteMasterPasswordUseCase(
        localStorage: a.local,
        ancestorStorage: a.ancestor,
        remote: remote,
        syncState: a.syncState,
        crypto: crypto,
        currentKey: a.session.key,
        currentHeader: a.session.header,
      );
      await expectLater(
        adopt.call(newPassword: _password),
        rejectedAs(RemoteVaultRejection.rollback),
      );
    });

    test('el merge supera la revisión de los dos lados', () async {
      final a = await newDevice();
      await a.sync();
      final b = await restoredDevice();

      await a.addEntry('a1');
      await a.addEntry('a2');
      await a.sync();
      await b.addEntry('b1');

      final aRevision = remote.remoteFile!.header.revision;
      final bRevision = b.local.stored!.header.revision;
      expect(await b.sync(), isA<SyncMerged>());
      final merged = b.local.stored!.header.revision;
      expect(merged, greaterThan(aRevision));
      expect(merged, greaterThan(bRevision));
      expect(await a.sync(), isA<SyncDownloaded>());
      expect(a.titles, {'a1', 'a2', 'b1'});
    });

    test('con un ancestro v1 (revisión 0) no hay contra qué comparar y se '
        'acepta', () async {
      final a = await newDevice();
      await a.sync();
      final b = await restoredDevice();
      b.ancestor.stored = VaultFile(
        header: b.ancestor.stored!.header.copyWith(revision: 0),
        encryptedPayload: b.ancestor.stored!.encryptedPayload,
      );

      await a.addEntry('nueva');
      await a.sync();
      expect(await b.sync(), isA<SyncDownloaded>());
    });
  });

  group('Recuperación: subir la versión de este dispositivo', () {
    test('reemplaza la nube vieja y la sync vuelve a estar al día', () async {
      final a = await newDevice();
      await a.sync();
      final oldCopy = remote.remoteFile!;
      await a.addEntry('nueva');
      await a.sync();

      remote.remoteFile = oldCopy;
      await expectLater(a.sync(), rejectedAs(RemoteVaultRejection.rollback));

      expect(await a.replaceRemoteWithLocal(), isA<SyncUploaded>());
      expect(remote.remoteFile, same(a.local.stored));
      expect(await a.sync(), isA<SyncUpToDate>());
    });
  });
}
