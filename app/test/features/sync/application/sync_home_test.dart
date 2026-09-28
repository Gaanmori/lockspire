// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Lockspire

import 'package:flutter_test/flutter_test.dart';
import 'package:lockspire/features/sync/application/move_vault_to_provider_use_case.dart';
import 'package:lockspire/features/sync/application/sync_vault_use_case.dart';
import 'package:lockspire/features/sync/domain/ports/active_sync_provider_port.dart';
import 'package:lockspire/features/vault/application/create_vault_use_case.dart';
import 'package:lockspire/features/vault/application/save_vault_use_case.dart';
import 'package:lockspire/features/vault/application/unlock_vault_use_case.dart';
import 'package:lockspire/features/vault/application/unlocked_vault_result.dart';
import 'package:lockspire/features/vault/domain/entities/vault_entry.dart';

import '../../vault/application/fakes.dart';
import 'fakes.dart';

const _password = 'contraseña de prueba larga';

VaultEntry _entry(String id) => VaultEntry(
  id: id,
  type: VaultEntryType.password,
  title: id,
  createdAt: DateTime.utc(2026, 1, 1),
  modifiedAt: DateTime.utc(2026, 1, 1),
  fields: const {},
);

/// Un dispositivo con su bóveda local, su ancestro y su nube activa.
class _Device {
  final local = FakeVaultStoragePort();
  final ancestor = FakeVaultStoragePort();
  final syncState = FakeSyncStatePort();
  final FakeCryptoPort crypto;
  final Map<SyncProviderId, FakeSyncPort> clouds;
  SyncProviderId active;
  late UnlockedVaultResult session;

  _Device(this.crypto, this.clouds, this.active);

  Future<SyncResult> sync() async {
    final result = await SyncVaultUseCase(
      localStorage: local,
      ancestorStorage: ancestor,
      remote: clouds[active]!,
      syncState: syncState,
      crypto: crypto,
      key: session.key,
      header: session.header,
      activeProvider: active,
    ).call();
    await _reload();
    return result;
  }

  /// Lo que hace la app al conectar [to] con la bóveda desbloqueada.
  Future<void> moveTo(SyncProviderId to, {bool fromActive = true}) async {
    await MoveVaultToProviderUseCase(
      localStorage: local,
      ancestorStorage: ancestor,
      syncState: syncState,
      crypto: crypto,
      key: session.key,
      header: session.header,
      from: fromActive ? clouds[active] : null,
      fromId: fromActive ? active : null,
      to: clouds[to]!,
      toId: to,
    ).call();
    active = to;
    await _reload();
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

  Future<void> _reload() async {
    session = await UnlockVaultUseCase(
      storage: local,
      crypto: crypto,
    ).reloadWithKey(key: session.key);
  }

  String? get home => session.vault.syncHome;
  Set<String> get ids => session.vault.entries.map((e) => e.id).toSet();
}

void main() {
  const drive = SyncProviderId.googleDrive;
  const oneDrive = SyncProviderId.oneDrive;

  late FakeCryptoPort crypto;
  late Map<SyncProviderId, FakeSyncPort> clouds;

  setUp(() {
    crypto = FakeCryptoPort();
    clouds = {drive: FakeSyncPort(), oneDrive: FakeSyncPort()};
  });

  /// Dispositivo que crea la bóveda y la deja en Drive con `syncHome`.
  Future<_Device> founder() async {
    final device = _Device(crypto, clouds, drive);
    device.session = await CreateVaultUseCase(
      storage: device.local,
      crypto: crypto,
    ).call(masterPassword: _password);
    await device.moveTo(drive, fromActive: false);
    return device;
  }

  /// Segundo dispositivo que restaura la bóveda de [cloud].
  Future<_Device> restored(SyncProviderId cloud) async {
    final device = _Device(crypto, clouds, cloud);
    device.local.stored = clouds[cloud]!.remoteFile;
    device.session = await UnlockVaultUseCase(
      storage: device.local,
      crypto: crypto,
    ).call(masterPassword: _password);
    await device.sync();
    return device;
  }

  Future<String?> homeIn(SyncProviderId cloud, _Device reader) async {
    final other = _Device(crypto, clouds, cloud);
    other.local.stored = clouds[cloud]!.remoteFile;
    other.session = await UnlockVaultUseCase(
      storage: other.local,
      crypto: crypto,
    ).reloadWithKey(key: reader.session.key);
    return other.home;
  }

  test('la primera nube queda registrada en la bóveda y en la nube', () async {
    final a = await founder();
    expect(a.home, 'googleDrive');
    expect(await homeIn(drive, a), 'googleDrive');
    expect(await a.sync(), isA<SyncUpToDate>());
  });

  test('sincronizar con una nube que no es la de la bóveda no sube ni baja '
      'nada', () async {
    final a = await founder();
    a.active = oneDrive;
    await expectLater(
      a.sync(),
      throwsA(
        isA<SyncHomeMismatchException>()
            .having((e) => e.vaultHome, 'vaultHome', drive)
            .having((e) => e.active, 'active', oneDrive),
      ),
    );
    expect(clouds[oneDrive]!.remoteFile, isNull);
  });

  test('mudar a una nube vacía: deja el aviso en la vieja y sube a la '
      'nueva', () async {
    final a = await founder();
    await a.addEntry('e1');
    await a.sync();

    await a.moveTo(oneDrive);

    expect(a.home, 'oneDrive');
    expect(await homeIn(drive, a), 'oneDrive');
    expect(await homeIn(oneDrive, a), 'oneDrive');
    expect(await a.sync(), isA<SyncUpToDate>());
  });

  test('el otro dispositivo recibe el aviso: SyncVaultMoved, y deja de '
      'subir a la nube vieja', () async {
    final a = await founder();
    final b = await restored(drive);
    await a.moveTo(oneDrive);
    final uploadsBefore = clouds[drive]!.uploadVaultCalls;

    final result = await b.sync();

    expect(result, isA<SyncVaultMoved>());
    expect((result as SyncVaultMoved).to, oneDrive);
    expect(b.home, 'oneDrive');
    expect(clouds[drive]!.uploadVaultCalls, uploadsBefore);

    // Sigue en Drive: la sync se niega hasta que conecte OneDrive.
    await expectLater(b.sync(), throwsA(isA<SyncHomeMismatchException>()));
  });

  test('cambios locales pendientes al recibir el aviso: se guardan solo en '
      'local y llegan a la nube nueva al conectarla', () async {
    final a = await founder();
    final b = await restored(drive);
    await a.moveTo(oneDrive);
    await b.addEntry('de-b');
    final uploadsBefore = clouds[drive]!.uploadVaultCalls;

    expect(await b.sync(), isA<SyncVaultMoved>());
    expect(clouds[drive]!.uploadVaultCalls, uploadsBefore);
    expect(b.ids, contains('de-b'));
    expect(b.home, 'oneDrive');

    // Conectar OneDrive en B: ya es la nube de la bóveda, solo se activa.
    b.active = oneDrive;
    await b.sync();
    await a.sync();
    expect(a.ids, contains('de-b'));
  });

  test('mudar a una nube que ya tiene la misma bóveda fusiona sin perder '
      'nada de ninguno de los dos lados', () async {
    final a = await founder();
    final b = await restored(drive);
    await a.moveTo(oneDrive);
    await a.addEntry('de-a');
    await a.sync();

    // B no recibió el aviso (no sincronizó) y también se muda a OneDrive.
    await b.addEntry('de-b');
    await b.moveTo(oneDrive);

    expect(b.ids, containsAll(['de-a', 'de-b']));
    expect(b.home, 'oneDrive');
    await a.sync();
    expect(a.ids, containsAll(['de-a', 'de-b']));
  });

  test('si la nube nueva tiene otra bóveda, la mudanza se cancela sin '
      'tocar nada', () async {
    final a = await founder();
    final stranger = _Device(crypto, clouds, oneDrive);
    stranger.session = await CreateVaultUseCase(
      storage: stranger.local,
      crypto: crypto,
    ).call(masterPassword: _password);
    await stranger.moveTo(oneDrive, fromActive: false);
    final driveBefore = clouds[drive]!.remoteFile;
    final localBefore = a.local.stored;

    await expectLater(
      a.moveTo(oneDrive),
      throwsA(
        isA<RemoteVaultRejectedException>().having(
          (e) => e.reason,
          'reason',
          RemoteVaultRejection.differentVault,
        ),
      ),
    );
    expect(clouds[drive]!.remoteFile, same(driveBefore));
    expect(a.local.stored, same(localBefore));
  });
}
