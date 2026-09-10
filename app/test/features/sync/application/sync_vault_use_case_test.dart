// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Lockspire

import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lockspire/features/sync/application/sync_vault_use_case.dart';
import 'package:lockspire/features/vault/domain/entities/vault.dart';
import 'package:lockspire/features/vault/domain/entities/vault_entry.dart';
import 'package:lockspire/features/vault/domain/ports/vault_storage_port.dart';
import 'package:lockspire/features/vault/domain/vault_file_codec.dart';

import '../../vault/application/fakes.dart';
import 'fakes.dart';

/// Mismo cálculo que usa [SyncVaultUseCase] internamente (hash del blob
/// codificado) — se recalcula aquí para preparar el "último hash
/// sincronizado" de los tests sin depender de internals privados.
String _hashOf(VaultFile file) =>
    sha256.convert(VaultFileCodec.encode(file)).toString();

final _testKey = Uint8List.fromList(utf8.encode('clave-de-prueba'));

VaultHeader _testHeader({String vaultId = 'vault-1'}) => VaultHeader(
  formatVersion: 1,
  formatMinReaderVersion: 1,
  salt: Uint8List.fromList(List.filled(16, 9)),
  nonce: Uint8List.fromList(List.filled(24, 9)),
  vaultId: vaultId,
  createdAt: DateTime.utc(2026, 1, 1),
  kdfParams: const Argon2Params(
    memoryKib: 65536,
    iterations: 3,
    parallelism: 1,
  ),
);

VaultFile _sampleFile(List<int> payload, {String vaultId = 'vault-1'}) {
  return VaultFile(
    header: _testHeader(vaultId: vaultId),
    encryptedPayload: Uint8List.fromList(payload),
  );
}

/// Encripta [vault] de verdad con [crypto] — necesario para los tests que
/// ejercitan la rama de merge, que decripta local/remoto/ancestro.
Future<VaultFile> _encryptVault(
  Vault vault,
  FakeCryptoPort crypto, {
  VaultHeader? header,
}) async {
  final h = header ?? _testHeader(vaultId: vault.vaultId);
  final encrypted = await crypto.encrypt(
    key: _testKey,
    plaintext: vault.toJsonBytes(),
    aad: h.toAadBytes(),
  );
  return VaultFile(
    header: VaultHeader(
      formatVersion: h.formatVersion,
      formatMinReaderVersion: h.formatMinReaderVersion,
      salt: h.salt,
      nonce: encrypted.nonce,
      vaultId: h.vaultId,
      createdAt: h.createdAt,
      kdfParams: h.kdfParams,
    ),
    encryptedPayload: encrypted.ciphertext,
  );
}

VaultEntry _entry(
  String id,
  String title, {
  DateTime? modifiedAt,
  bool deleted = false,
  Map<String, String> fields = const {},
}) {
  final t = modifiedAt ?? DateTime.utc(2026, 1, 1);
  return VaultEntry(
    id: id,
    type: VaultEntryType.password,
    title: title,
    createdAt: t,
    modifiedAt: t,
    deleted: deleted,
    fields: fields,
  );
}

void main() {
  group('SyncVaultUseCase — ramas simples (sin necesitar decriptar)', () {
    test('solo existe local → sube', () async {
      final localStorage = FakeVaultStoragePort()..stored = _sampleFile([1]);
      final remote = FakeSyncPort();
      final syncState = FakeSyncStatePort();

      final result = await SyncVaultUseCase(
        localStorage: localStorage,
        ancestorStorage: FakeVaultStoragePort(),
        remote: remote,
        syncState: syncState,
        crypto: FakeCryptoPort(),
        key: _testKey,
        header: _testHeader(),
      ).call();

      expect(result, isA<SyncUploaded>());
      expect(remote.remoteFile, isNotNull);
      expect(await syncState.lastSyncedHash(), isNotNull);
    });

    test('solo existe remoto → baja', () async {
      final localStorage = FakeVaultStoragePort();
      final remote = FakeSyncPort()..remoteFile = _sampleFile([2]);
      final syncState = FakeSyncStatePort();

      final result = await SyncVaultUseCase(
        localStorage: localStorage,
        ancestorStorage: FakeVaultStoragePort(),
        remote: remote,
        syncState: syncState,
        crypto: FakeCryptoPort(),
        key: _testKey,
        header: _testHeader(),
      ).call();

      expect(result, isA<SyncDownloaded>());
      expect(localStorage.stored, isNotNull);
    });

    test('local y remoto ya coinciden → al día', () async {
      final file = _sampleFile([3]);
      final localStorage = FakeVaultStoragePort()..stored = file;
      final remote = FakeSyncPort()..remoteFile = file;
      final syncState = FakeSyncStatePort();

      final result = await SyncVaultUseCase(
        localStorage: localStorage,
        ancestorStorage: FakeVaultStoragePort(),
        remote: remote,
        syncState: syncState,
        crypto: FakeCryptoPort(),
        key: _testKey,
        header: _testHeader(),
      ).call();

      expect(result, isA<SyncUpToDate>());
    });

    test('solo cambió el local desde la última sync → sube', () async {
      final oldFile = _sampleFile([4]);
      final newLocalFile = _sampleFile([4, 4]);
      final localStorage = FakeVaultStoragePort()..stored = newLocalFile;
      final remote = FakeSyncPort()..remoteFile = oldFile;
      final syncState = FakeSyncStatePort();
      await syncState.saveLastSyncedHash(_hashOf(oldFile));

      final result = await SyncVaultUseCase(
        localStorage: localStorage,
        ancestorStorage: FakeVaultStoragePort(),
        remote: remote,
        syncState: syncState,
        crypto: FakeCryptoPort(),
        key: _testKey,
        header: _testHeader(),
      ).call();

      expect(result, isA<SyncUploaded>());
      expect(remote.remoteFile, same(newLocalFile));
      expect(localStorage.stored, same(newLocalFile));
    });

    test('solo cambió el remoto desde la última sync → baja', () async {
      final oldFile = _sampleFile([5]);
      final newRemoteFile = _sampleFile([5, 5]);
      final localStorage = FakeVaultStoragePort()..stored = oldFile;
      final remote = FakeSyncPort()..remoteFile = newRemoteFile;
      final syncState = FakeSyncStatePort();
      await syncState.saveLastSyncedHash(_hashOf(oldFile));

      final result = await SyncVaultUseCase(
        localStorage: localStorage,
        ancestorStorage: FakeVaultStoragePort(),
        remote: remote,
        syncState: syncState,
        crypto: FakeCryptoPort(),
        key: _testKey,
        header: _testHeader(),
      ).call();

      expect(result, isA<SyncDownloaded>());
      expect(localStorage.stored, same(newRemoteFile));
    });

    test(
      'sin bóveda local ni remota → falla explícitamente, no hay nada que sincronizar',
      () async {
        final useCase = SyncVaultUseCase(
          localStorage: FakeVaultStoragePort(),
          ancestorStorage: FakeVaultStoragePort(),
          remote: FakeSyncPort(),
          syncState: FakeSyncStatePort(),
          crypto: FakeCryptoPort(),
          key: _testKey,
          header: _testHeader(),
        );

        await expectLater(useCase.call(), throwsA(isA<StateError>()));
      },
    );
  });

  group('SyncVaultUseCase — merge de 3 vías (ADR 0006)', () {
    test(
      'cambiaron los dos sin conflicto real → se resuelve solo, SyncMerged',
      () async {
        final crypto = FakeCryptoPort();
        final ancestor = Vault(
          vaultId: 'vault-1',
          schemaVersion: 1,
          entries: [_entry('a', 'Original'), _entry('b', 'Sin tocar')],
        );
        final ancestorFile = await _encryptVault(ancestor, crypto);

        final local = Vault(
          vaultId: 'vault-1',
          schemaVersion: 1,
          entries: [
            _entry('a', 'Editada en local', modifiedAt: DateTime.utc(2026, 2)),
            _entry('b', 'Sin tocar'),
          ],
        );
        final localFile = await _encryptVault(local, crypto);

        // El remoto también cambió (una entrada distinta a la que tocó
        // local) — si fuera idéntico al ancestro, este escenario en
        // realidad sería "solo cambió local" (rama rápida por hash, sin
        // llegar nunca a decriptar/mergear nada).
        final remote = Vault(
          vaultId: 'vault-1',
          schemaVersion: 1,
          entries: [
            _entry('a', 'Original'),
            _entry('b', 'Editada en remoto', modifiedAt: DateTime.utc(2026, 2)),
          ],
        );
        final remoteFile = await _encryptVault(remote, crypto);

        final localStorage = FakeVaultStoragePort()..stored = localFile;
        final ancestorStorage = FakeVaultStoragePort()..stored = ancestorFile;
        final remotePort = FakeSyncPort()..remoteFile = remoteFile;
        final syncState = FakeSyncStatePort();
        await syncState.saveLastSyncedHash(_hashOf(ancestorFile));

        final result = await SyncVaultUseCase(
          localStorage: localStorage,
          ancestorStorage: ancestorStorage,
          remote: remotePort,
          syncState: syncState,
          crypto: crypto,
          key: _testKey,
          header: _testHeader(),
        ).call();

        expect(result, isA<SyncMerged>());
        expect((result as SyncMerged).autoResolvedCount, 2);
        expect(remotePort.remoteFile, isNotNull);
        expect(ancestorStorage.stored, isNotNull);
      },
    );

    test('cambiaron los dos con conflicto real → SyncNeedsResolution, sin '
        'escribir ni subir nada', () async {
      final crypto = FakeCryptoPort();
      final ancestor = Vault(
        vaultId: 'vault-1',
        schemaVersion: 1,
        entries: [_entry('a', 'Original')],
      );
      final ancestorFile = await _encryptVault(ancestor, crypto);

      final local = Vault(
        vaultId: 'vault-1',
        schemaVersion: 1,
        entries: [
          _entry('a', 'Editada en local', modifiedAt: DateTime.utc(2026, 2)),
        ],
      );
      final localFile = await _encryptVault(local, crypto);

      final remote = Vault(
        vaultId: 'vault-1',
        schemaVersion: 1,
        entries: [
          _entry(
            'a',
            'Editada distinto en remoto',
            modifiedAt: DateTime.utc(2026, 3),
          ),
        ],
      );
      final remoteFile = await _encryptVault(remote, crypto);

      final localStorage = FakeVaultStoragePort()..stored = localFile;
      final ancestorStorage = FakeVaultStoragePort()..stored = ancestorFile;
      final remotePort = FakeSyncPort()..remoteFile = remoteFile;
      final syncState = FakeSyncStatePort();
      await syncState.saveLastSyncedHash(_hashOf(ancestorFile));

      final result = await SyncVaultUseCase(
        localStorage: localStorage,
        ancestorStorage: ancestorStorage,
        remote: remotePort,
        syncState: syncState,
        crypto: crypto,
        key: _testKey,
        header: _testHeader(),
      ).call();

      expect(result, isA<SyncNeedsResolution>());
      final pending = result as SyncNeedsResolution;
      expect(pending.conflicts, hasLength(1));
      expect(pending.conflicts.single.local.title, 'Editada en local');
      expect(
        pending.conflicts.single.remote.title,
        'Editada distinto en remoto',
      );
      // Nada se escribió ni se subió todavía.
      expect(localStorage.stored, same(localFile));
      expect(remotePort.remoteFile, same(remoteFile));
      expect(ancestorStorage.stored, same(ancestorFile));
    });

    test(
      'completeMerge aplica las resoluciones, escribe y sube el resultado',
      () async {
        final crypto = FakeCryptoPort();
        final ancestor = Vault(
          vaultId: 'vault-1',
          schemaVersion: 1,
          entries: [_entry('a', 'Original')],
        );
        final ancestorFile = await _encryptVault(ancestor, crypto);
        final local = Vault(
          vaultId: 'vault-1',
          schemaVersion: 1,
          entries: [
            _entry('a', 'Editada en local', modifiedAt: DateTime.utc(2026, 2)),
          ],
        );
        final localFile = await _encryptVault(local, crypto);
        final remote = Vault(
          vaultId: 'vault-1',
          schemaVersion: 1,
          entries: [
            _entry(
              'a',
              'Editada distinto en remoto',
              modifiedAt: DateTime.utc(2026, 3),
            ),
          ],
        );
        final remoteFile = await _encryptVault(remote, crypto);

        final localStorage = FakeVaultStoragePort()..stored = localFile;
        final ancestorStorage = FakeVaultStoragePort()..stored = ancestorFile;
        final remotePort = FakeSyncPort()..remoteFile = remoteFile;
        final syncState = FakeSyncStatePort();
        await syncState.saveLastSyncedHash(_hashOf(ancestorFile));

        final useCase = SyncVaultUseCase(
          localStorage: localStorage,
          ancestorStorage: ancestorStorage,
          remote: remotePort,
          syncState: syncState,
          crypto: crypto,
          key: _testKey,
          header: _testHeader(),
        );

        final pending = await useCase.call() as SyncNeedsResolution;
        final chosen = pending.conflicts.single.remote;

        final result = await useCase.completeMerge(pending, {'a': chosen});

        expect(result, isA<SyncMerged>());
        expect(localStorage.stored, isNot(same(localFile)));
        expect(remotePort.remoteFile, isNot(same(remoteFile)));
      },
    );

    test('completeMerge cuando el remoto cambió de nuevo mientras se '
        'resolvía → SyncStaleMergeException, sin escribir nada', () async {
      final crypto = FakeCryptoPort();
      final ancestor = Vault(
        vaultId: 'vault-1',
        schemaVersion: 1,
        entries: [_entry('a', 'Original')],
      );
      final ancestorFile = await _encryptVault(ancestor, crypto);
      final local = Vault(
        vaultId: 'vault-1',
        schemaVersion: 1,
        entries: [
          _entry('a', 'Editada en local', modifiedAt: DateTime.utc(2026, 2)),
        ],
      );
      final localFile = await _encryptVault(local, crypto);
      final remote = Vault(
        vaultId: 'vault-1',
        schemaVersion: 1,
        entries: [
          _entry(
            'a',
            'Editada distinto en remoto',
            modifiedAt: DateTime.utc(2026, 3),
          ),
        ],
      );
      final remoteFile = await _encryptVault(remote, crypto);

      final localStorage = FakeVaultStoragePort()..stored = localFile;
      final ancestorStorage = FakeVaultStoragePort()..stored = ancestorFile;
      final remotePort = FakeSyncPort()..remoteFile = remoteFile;
      final syncState = FakeSyncStatePort();
      await syncState.saveLastSyncedHash(_hashOf(ancestorFile));

      final useCase = SyncVaultUseCase(
        localStorage: localStorage,
        ancestorStorage: ancestorStorage,
        remote: remotePort,
        syncState: syncState,
        crypto: crypto,
        key: _testKey,
        header: _testHeader(),
      );

      final pending = await useCase.call() as SyncNeedsResolution;

      // El remoto sigue moviéndose mientras el usuario resolvía.
      final remoteAgain = Vault(
        vaultId: 'vault-1',
        schemaVersion: 1,
        entries: [
          _entry('a', 'Cambió de nuevo', modifiedAt: DateTime.utc(2026, 4)),
        ],
      );
      remotePort.remoteFile = await _encryptVault(remoteAgain, crypto);

      await expectLater(
        useCase.completeMerge(pending, {'a': pending.conflicts.single.remote}),
        throwsA(isA<SyncStaleMergeException>()),
      );
      expect(localStorage.stored, same(localFile));
    });
  });
}
