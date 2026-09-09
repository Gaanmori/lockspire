// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Lockspire

import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lockspire/features/sync/application/sync_vault_use_case.dart';
import 'package:lockspire/features/vault/domain/ports/vault_storage_port.dart';
import 'package:lockspire/features/vault/domain/vault_file_codec.dart';

import '../../vault/application/fakes.dart';
import 'fakes.dart';

/// Mismo cálculo que usa [SyncVaultUseCase] internamente (hash del blob
/// codificado) — se recalcula aquí para preparar el "último hash
/// sincronizado" de los tests sin depender de internals privados.
String _hashOf(VaultFile file) =>
    sha256.convert(VaultFileCodec.encode(file)).toString();

VaultFile _sampleFile(List<int> payload, {String vaultId = 'vault-1'}) {
  return VaultFile(
    header: VaultHeader(
      formatVersion: 1,
      formatMinReaderVersion: 1,
      salt: Uint8List.fromList(List.filled(16, 1)),
      nonce: Uint8List.fromList(List.filled(24, 2)),
      vaultId: vaultId,
      createdAt: DateTime.utc(2026, 1, 1),
      kdfParams: const Argon2Params(
        memoryKib: 65536,
        iterations: 3,
        parallelism: 1,
      ),
    ),
    encryptedPayload: Uint8List.fromList(payload),
  );
}

void main() {
  group('SyncVaultUseCase', () {
    test('solo existe local → sube', () async {
      final localStorage = FakeVaultStoragePort()..stored = _sampleFile([1]);
      final remote = FakeSyncPort();
      final syncState = FakeSyncStatePort();

      final result = await SyncVaultUseCase(
        localStorage: localStorage,
        remote: remote,
        syncState: syncState,
      )();

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
        remote: remote,
        syncState: syncState,
      )();

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
        remote: remote,
        syncState: syncState,
      )();

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
        remote: remote,
        syncState: syncState,
      )();

      expect(result, isA<SyncUploaded>());
      expect(remote.remoteFile, same(newLocalFile));
      // El remoto (que no cambió) no debe haber sobrescrito al local.
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
        remote: remote,
        syncState: syncState,
      )();

      expect(result, isA<SyncDownloaded>());
      expect(localStorage.stored, same(newRemoteFile));
    });

    test(
      'cambiaron los dos lados desde la última sync → conflicto, sin tocar nada',
      () async {
        final oldFile = _sampleFile([6]);
        final newLocalFile = _sampleFile([6, 6]);
        final newRemoteFile = _sampleFile([6, 7]);
        final localStorage = FakeVaultStoragePort()..stored = newLocalFile;
        final remote = FakeSyncPort()..remoteFile = newRemoteFile;
        final syncState = FakeSyncStatePort();
        await syncState.saveLastSyncedHash(_hashOf(oldFile));

        final result = await SyncVaultUseCase(
          localStorage: localStorage,
          remote: remote,
          syncState: syncState,
        )();

        expect(result, isA<SyncConflict>());
        // Ninguno de los dos lados debe haberse sobrescrito.
        expect(localStorage.stored, same(newLocalFile));
        expect(remote.remoteFile, same(newRemoteFile));
      },
    );

    test(
      'sin bóveda local ni remota → falla explícitamente, no hay nada que sincronizar',
      () async {
        final useCase = SyncVaultUseCase(
          localStorage: FakeVaultStoragePort(),
          remote: FakeSyncPort(),
          syncState: FakeSyncStatePort(),
        );

        await expectLater(useCase(), throwsA(isA<StateError>()));
      },
    );
  });
}
