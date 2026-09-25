// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Lockspire

import 'package:flutter_test/flutter_test.dart';
import 'package:lockspire/features/sync/application/adopt_remote_master_password_use_case.dart';
import 'package:lockspire/features/sync/application/sync_master_password_change_replica.dart';
import 'package:lockspire/features/sync/application/sync_vault_use_case.dart';
import 'package:lockspire/features/vault/application/change_master_password_use_case.dart';
import 'package:lockspire/features/vault/application/create_vault_use_case.dart';
import 'package:lockspire/features/vault/application/master_password_policy.dart';
import 'package:lockspire/features/vault/application/save_vault_use_case.dart';
import 'package:lockspire/features/vault/application/unlock_vault_use_case.dart';
import 'package:lockspire/features/vault/application/unlocked_vault_result.dart';
import 'package:lockspire/features/vault/domain/entities/vault_entry.dart';
import 'package:lockspire/features/vault/domain/ports/vault_storage_port.dart';

import '../../vault/application/fakes.dart';
import 'fakes.dart';

const _oldPassword = 'contraseña vieja de prueba';
const _newPassword = 'Tr3s-Tigres!Trigo nuevo';

VaultEntry _entry(String id, String title) => VaultEntry(
  id: id,
  type: VaultEntryType.password,
  title: title,
  createdAt: DateTime.utc(2026, 1, 1),
  modifiedAt: DateTime.utc(2026, 1, 1),
  fields: const {},
);

class _FailingSyncPort extends FakeSyncPort {
  bool failDownload = false;
  bool failUpload = false;

  @override
  Future<VaultFile> downloadVault() {
    if (failDownload) throw StateError('sin conexión');
    return super.downloadVault();
  }

  @override
  Future<void> uploadVault(VaultFile file) {
    if (failUpload) throw StateError('sin conexión');
    return super.uploadVault(file);
  }
}

/// Un dispositivo: su bóveda local, su ancestro y su estado de sync.
class _Device {
  final local = FakeVaultStoragePort();
  final ancestor = FakeVaultStoragePort();
  final syncState = FakeSyncStatePort();
  final FakeCryptoPort crypto;
  final FakeSyncPort? remote;
  late UnlockedVaultResult session;

  _Device(this.crypto, this.remote);

  SyncVaultUseCase sync() => SyncVaultUseCase(
    localStorage: local,
    ancestorStorage: ancestor,
    remote: remote!,
    syncState: syncState,
    crypto: crypto,
    key: session.key,
    header: session.header,
  );

  Future<SyncResult> syncAndReload() async {
    final result = await sync().call();
    session = await UnlockVaultUseCase(
      storage: local,
      crypto: crypto,
    ).reloadWithKey(key: session.key);
    return result;
  }

  ChangeMasterPasswordUseCase changePassword() => ChangeMasterPasswordUseCase(
    storage: local,
    crypto: crypto,
    replica: SyncMasterPasswordChangeReplica(
      localStorage: local,
      ancestorStorage: ancestor,
      remote: remote,
      syncState: syncState,
      crypto: crypto,
    ),
  );

  AdoptRemoteMasterPasswordUseCase adopt() => AdoptRemoteMasterPasswordUseCase(
    localStorage: local,
    ancestorStorage: ancestor,
    remote: remote!,
    syncState: syncState,
    crypto: crypto,
    currentKey: session.key,
    currentHeader: session.header,
  );

  Future<void> addEntry(VaultEntry entry) async {
    final vault = session.vault.copyWith(
      entries: [...session.vault.entries, entry],
    );
    await SaveVaultUseCase(storage: local, crypto: crypto).call(
      vault: vault,
      key: session.key,
      header: session.header,
      expectedFileHash: session.fileHash,
    );
    session = await UnlockVaultUseCase(
      storage: local,
      crypto: crypto,
    ).reloadWithKey(key: session.key);
  }
}

Future<void> _expectOpensWith(_Device device, String password) async {
  await UnlockVaultUseCase(
    storage: device.local,
    crypto: device.crypto,
  ).call(masterPassword: password);
}

void main() {
  late FakeCryptoPort crypto;

  setUp(() => crypto = FakeCryptoPort());

  Future<_Device> newDevice({FakeSyncPort? remote}) async {
    final device = _Device(crypto, remote);
    device.session = await CreateVaultUseCase(
      storage: device.local,
      crypto: crypto,
    ).call(masterPassword: _oldPassword);
    return device;
  }

  group('ChangeMasterPasswordUseCase sin sync (ADR 0018)', () {
    test('recifra con salt nuevo y conserva la bóveda', () async {
      final device = await newDevice();
      await device.addEntry(_entry('e1', 'Banco'));
      final before = device.local.stored!;

      final result = await device.changePassword().call(
        currentPassword: _oldPassword,
        newPassword: _newPassword,
      );

      final after = device.local.stored!;
      expect(after.header.vaultId, before.header.vaultId);
      expect(after.header.createdAt, before.header.createdAt);
      expect(after.header.salt, isNot(before.header.salt));
      expect(after.header.kdfParams, defaultArgon2Params);
      expect(result.vault.entries.single.title, 'Banco');
      await _expectOpensWith(device, _newPassword);
      await expectLater(
        _expectOpensWith(device, _oldPassword),
        throwsA(anything),
      );
    });

    test('contraseña actual incorrecta: no cambia nada', () async {
      final device = await newDevice();
      final before = device.local.stored;

      await expectLater(
        device.changePassword().call(
          currentPassword: 'no es esta',
          newPassword: _newPassword,
        ),
        throwsA(isA<IncorrectMasterPasswordException>()),
      );
      expect(device.local.stored, same(before));
    });

    test('contraseña nueva débil: se rechaza antes de derivar nada', () async {
      final device = await newDevice();
      final derivations = crypto.deriveKeyCalls;

      await expectLater(
        device.changePassword().call(
          currentPassword: _oldPassword,
          newPassword: '12345678',
        ),
        throwsA(
          isA<WeakMasterPasswordException>().having(
            (e) => e.problem,
            'problem',
            MasterPasswordProblem.tooShort,
          ),
        ),
      );
      expect(crypto.deriveKeyCalls, derivations);
    });
  });

  group('ChangeMasterPasswordUseCase con sync (ADR 0018)', () {
    test('sube la bóveda recifrada y la deja como ancestro', () async {
      final remote = FakeSyncPort();
      final device = await newDevice(remote: remote);
      await device.syncAndReload();

      await device.changePassword().call(
        currentPassword: _oldPassword,
        newPassword: _newPassword,
      );

      expect(remote.remoteFile, same(device.local.stored));
      expect(device.ancestor.stored, same(device.local.stored));
    });

    test('sin conexión al sincronizar antes: no cambia nada', () async {
      final remote = _FailingSyncPort();
      final device = await newDevice(remote: remote);
      await device.syncAndReload();
      final before = device.local.stored;
      remote.failDownload = true;

      await expectLater(
        device.changePassword().call(
          currentPassword: _oldPassword,
          newPassword: _newPassword,
        ),
        throwsA(isA<StateError>()),
      );
      expect(device.local.stored, same(before));
      await _expectOpensWith(device, _oldPassword);
    });

    test(
      'falla la subida: la bóveda local sigue con la contraseña vieja',
      () async {
        final remote = _FailingSyncPort();
        final device = await newDevice(remote: remote);
        await device.syncAndReload();
        final remoteBefore = remote.remoteFile;
        remote.failUpload = true;

        await expectLater(
          device.changePassword().call(
            currentPassword: _oldPassword,
            newPassword: _newPassword,
          ),
          throwsA(isA<StateError>()),
        );
        await _expectOpensWith(device, _oldPassword);
        expect(remote.remoteFile, same(remoteBefore));
      },
    );
  });

  group('Otro dispositivo adopta la contraseña nueva (ADR 0018)', () {
    late FakeSyncPort remote;
    late _Device a;
    late _Device b;

    setUp(() async {
      remote = FakeSyncPort();
      a = await newDevice(remote: remote);
      await a.syncAndReload();
      // B restaura la misma bóveda desde la nube.
      b = _Device(crypto, remote);
      b.local.stored = remote.remoteFile;
      b.session = await UnlockVaultUseCase(
        storage: b.local,
        crypto: crypto,
      ).call(masterPassword: _oldPassword);
      await b.syncAndReload();
    });

    test('la sync de B rechaza el remoto sin tocar nada local', () async {
      a.session = await a.changePassword().call(
        currentPassword: _oldPassword,
        newPassword: _newPassword,
      );
      final bBefore = b.local.stored;

      await expectLater(
        b.sync().call(),
        throwsA(
          isA<RemoteVaultRejectedException>().having(
            (e) => e.reason,
            'reason',
            RemoteVaultRejection.passwordChanged,
          ),
        ),
      );
      expect(b.local.stored, same(bBefore));
    });

    test('con la contraseña equivocada, B no cambia nada', () async {
      a.session = await a.changePassword().call(
        currentPassword: _oldPassword,
        newPassword: _newPassword,
      );
      final bBefore = b.local.stored;

      await expectLater(
        b.adopt().call(newPassword: 'otra cosa'),
        throwsA(isA<IncorrectMasterPasswordException>()),
      );
      expect(b.local.stored, same(bBefore));
    });

    test(
      'B adopta y conserva sus cambios hechos con la contraseña vieja',
      () async {
        await b.addEntry(_entry('b1', 'Hecha en B sin conexión'));
        await a.addEntry(_entry('a1', 'Hecha en A'));
        a.session = await a.changePassword().call(
          currentPassword: _oldPassword,
          newPassword: _newPassword,
        );

        b.session = await b.adopt().call(newPassword: _newPassword);

        final titles = b.session.vault.entries.map((e) => e.title).toSet();
        expect(titles, {'Hecha en A', 'Hecha en B sin conexión'});
        await _expectOpensWith(b, _newPassword);
        expect(remote.remoteFile, same(b.local.stored));

        // Desde ahí todo sigue sincronizando normal, en los dos.
        expect(await b.syncAndReload(), isA<SyncUpToDate>());
        expect(await a.syncAndReload(), isA<SyncDownloaded>());
        expect(a.session.vault.entries.map((e) => e.title).toSet(), titles);
      },
    );

    test('B sin cambios propios adopta el remoto tal cual', () async {
      a.session = await a.changePassword().call(
        currentPassword: _oldPassword,
        newPassword: _newPassword,
      );
      final uploads = remote.uploadVaultCalls;

      b.session = await b.adopt().call(newPassword: _newPassword);

      expect(b.local.stored, same(remote.remoteFile));
      expect(remote.uploadVaultCalls, uploads);
    });
  });
}
