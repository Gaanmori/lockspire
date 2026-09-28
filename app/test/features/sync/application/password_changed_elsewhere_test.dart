// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Lockspire

import 'package:flutter_test/flutter_test.dart';
import 'package:lockspire/features/sync/application/sync_master_password_change_replica.dart';
import 'package:lockspire/features/sync/application/sync_password_changed_elsewhere.dart';
import 'package:lockspire/features/sync/application/sync_vault_use_case.dart';
import 'package:lockspire/features/vault/application/change_master_password_use_case.dart';
import 'package:lockspire/features/vault/application/create_vault_use_case.dart';
import 'package:lockspire/features/vault/application/password_changed_elsewhere_port.dart';
import 'package:lockspire/features/vault/application/save_vault_use_case.dart';
import 'package:lockspire/features/vault/application/unlock_vault_use_case.dart';
import 'package:lockspire/features/vault/application/unlocked_vault_result.dart';
import 'package:lockspire/features/vault/domain/entities/vault_entry.dart';

import '../../vault/application/fakes.dart';
import 'fakes.dart';

const _password = 'contraseña de prueba larga';
const _newPassword = 'Tr3s-Tigres!Trigo nuevo';

VaultEntry _entry(String id) => VaultEntry(
  id: id,
  type: VaultEntryType.password,
  title: id,
  createdAt: DateTime.utc(2026, 1, 1),
  modifiedAt: DateTime.utc(2026, 1, 1),
  fields: const {},
);

class _Device {
  final local = FakeVaultStoragePort();
  final ancestor = FakeVaultStoragePort();
  final syncState = FakeSyncStatePort();
  final FakeCryptoPort crypto;
  final FakeSyncPort remote;
  late UnlockedVaultResult session;

  _Device(this.crypto, this.remote);

  SyncPasswordChangedElsewhere get port => SyncPasswordChangedElsewhere(
    localStorage: local,
    ancestorStorage: ancestor,
    remote: remote,
    syncState: syncState,
    crypto: crypto,
  );

  Future<SyncResult> sync() async {
    final result = await SyncVaultUseCase(
      localStorage: local,
      ancestorStorage: ancestor,
      remote: remote,
      syncState: syncState,
      crypto: crypto,
      key: session.key,
      header: session.header,
    ).call();
    await _reload();
    return result;
  }

  Future<void> addEntry(String id) async {
    await SaveVaultUseCase(storage: local, crypto: crypto).call(
      vault: session.vault.withEntryAdded(_entry(id)),
      key: session.key,
      header: session.header,
      expectedFileHash: session.fileHash,
    );
    await _reload();
  }

  Future<void> changePassword() async {
    session = await ChangeMasterPasswordUseCase(
      storage: local,
      crypto: crypto,
      replica: SyncMasterPasswordChangeReplica(
        localStorage: local,
        ancestorStorage: ancestor,
        remote: remote,
        syncState: syncState,
        crypto: crypto,
      ),
    ).call(currentPassword: _password, newPassword: _newPassword);
  }

  Future<void> _reload() async {
    session = await UnlockVaultUseCase(
      storage: local,
      crypto: crypto,
    ).reloadWithKey(key: session.key);
  }

  Set<String> get ids => session.vault.entries.map((e) => e.id).toSet();
}

void main() {
  late FakeCryptoPort crypto;
  late FakeSyncPort remote;

  setUp(() {
    crypto = FakeCryptoPort();
    remote = FakeSyncPort();
  });

  /// A crea y sube; B restaura. Luego A cambia la contraseña.
  Future<({_Device a, _Device b})> passwordChangedOnA() async {
    final a = _Device(crypto, remote);
    a.session = await CreateVaultUseCase(
      storage: a.local,
      crypto: crypto,
    ).call(masterPassword: _password);
    await a.sync();

    final b = _Device(crypto, remote);
    b.local.stored = remote.remoteFile;
    b.session = await UnlockVaultUseCase(
      storage: b.local,
      crypto: crypto,
    ).call(masterPassword: _password);
    await b.sync();

    await a.addEntry('de-a');
    await a.changePassword();
    return (a: a, b: b);
  }

  group('Detectar el cambio sin desbloquear (ADR 0024)', () {
    test('mirando solo el header de la nube, lo detecta y lo anota', () async {
      final (:a, :b) = await passwordChangedOnA();
      expect(await b.port.isPending(), isFalse);

      expect(await b.port.checkRemote(), isTrue);
      expect(await b.port.isPending(), isTrue);
    });

    test('sin cambios en la nube, no anota nada', () async {
      final (:a, :b) = await passwordChangedOnA();
      expect(await a.port.checkRemote(), isFalse);

      final c = _Device(crypto, FakeSyncPort()..remoteFile = b.local.stored);
      c.local.stored = b.local.stored;
      c.ancestor.stored = b.ancestor.stored;
      await c.syncState.saveLastSyncedHash(
        await b.syncState.lastSyncedHash() ?? '',
      );
      expect(await c.port.checkRemote(), isFalse);
    });

    test('una copia vieja con otro salt es rollback, no un cambio de '
        'contraseña', () async {
      final (:a, :b) = await passwordChangedOnA();
      final oldPasswordCopy = b.ancestor.stored;
      await b.port.unlockWithNewPassword(newPassword: _newPassword);

      // La nube vuelve a la copia de antes del cambio (otro salt, revisión
      // más vieja que la última sincronizada).
      remote.remoteFile = oldPasswordCopy;
      expect(await b.port.checkRemote(), isFalse);
      expect(await b.port.isPending(), isFalse);
    });

    test('sin red devuelve lo ya sabido y no lanza', () async {
      final (:a, :b) = await passwordChangedOnA();
      await b.syncState.setPasswordChangedElsewhere(true);
      final offline = SyncPasswordChangedElsewhere(
        localStorage: b.local,
        ancestorStorage: b.ancestor,
        remote: _OfflineSyncPort(),
        syncState: b.syncState,
        crypto: crypto,
      );
      expect(await offline.checkRemote(), isTrue);
    });
  });

  group('Entrar con la contraseña nueva (ADR 0024)', () {
    test('sin cambios locales, basta la contraseña nueva', () async {
      final (:a, :b) = await passwordChangedOnA();
      await b.port.checkRemote();

      final result = await b.port.unlockWithNewPassword(
        newPassword: _newPassword,
      );

      expect(result.vault.entries.map((e) => e.id), contains('de-a'));
      expect(await b.port.isPending(), isFalse);
      // Queda con la contraseña nueva: se desbloquea con ella.
      await UnlockVaultUseCase(
        storage: b.local,
        crypto: crypto,
      ).call(masterPassword: _newPassword);
    });

    test('una contraseña que no es la nueva no cambia nada', () async {
      final (:a, :b) = await passwordChangedOnA();
      final before = b.local.stored;

      await expectLater(
        b.port.unlockWithNewPassword(newPassword: _password),
        throwsA(isA<IncorrectMasterPasswordException>()),
      );
      expect(b.local.stored, same(before));
    });

    test('con cambios locales sin sincronizar pide también la anterior, y '
        'con ella los conserva', () async {
      final (:a, :b) = await passwordChangedOnA();
      await b.addEntry('de-b');
      final before = b.local.stored;

      await expectLater(
        b.port.unlockWithNewPassword(newPassword: _newPassword),
        throwsA(isA<PreviousPasswordRequiredException>()),
      );
      expect(b.local.stored, same(before));

      await expectLater(
        b.port.unlockWithNewPassword(
          newPassword: _newPassword,
          previousPassword: 'no es esta',
        ),
        throwsA(isA<IncorrectPreviousPasswordException>()),
      );
      expect(b.local.stored, same(before));

      final result = await b.port.unlockWithNewPassword(
        newPassword: _newPassword,
        previousPassword: _password,
      );
      expect(
        result.vault.entries.map((e) => e.id),
        containsAll(['de-a', 'de-b']),
      );
      expect(await b.port.isPending(), isFalse);

      a.session = await UnlockVaultUseCase(
        storage: a.local,
        crypto: crypto,
      ).call(masterPassword: _newPassword);
      await a.sync();
      expect(a.ids, contains('de-b'));
    });
  });
}

class _OfflineSyncPort extends FakeSyncPort {
  @override
  Future<bool> remoteVaultExists() async => throw Exception('sin red');
}
