// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Gabriel Ángel Montoya Rico

import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lockspire/shared/domain/app_problem.dart';
import 'package:lockspire/features/sync/application/sync_vault_use_case.dart';
import 'package:lockspire/features/vault/domain/entities/vault.dart';
import 'package:lockspire/features/vault/domain/entities/vault_entry.dart';
import 'package:lockspire/features/vault/domain/ports/crypto_port.dart';
import 'package:lockspire/features/vault/domain/ports/vault_storage_port.dart';
import 'package:lockspire/features/vault/domain/vault_file_codec.dart';

import '../../../support/fakes/vault_fakes.dart';
import '../../../support/fakes/sync_fakes.dart';

import '../../../support/builders.dart';

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
  Uint8List? key,
}) async {
  final h = header ?? _testHeader(vaultId: vault.vaultId);
  final encrypted = await crypto.encrypt(
    key: key ?? _testKey,
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
}) => anEntry(
  id: id,
  title: title,
  createdAt: modifiedAt,
  deleted: deleted,
  fields: fields,
);

void main() {
  // Revisión 2026-09-25, hallazgo S1: un archivo remoto que no se descifra
  // con la clave de la sesión (o es otra bóveda) nunca debe tocar nada
  // local. Antes se copiaba sobre la bóveda y el ancestro.
  group('SyncVaultUseCase — rechaza bóvedas remotas no auténticas (S1)', () {
    final otherKey = Uint8List.fromList(utf8.encode('clave-del-atacante'));

    Future<
      ({
        FakeVaultStoragePort local,
        FakeVaultStoragePort ancestor,
        FakeSyncStatePort state,
        FakeSyncPort remote,
        SyncVaultUseCase useCase,
      })
    >
    setUpSynced(FakeCryptoPort crypto) async {
      final original = await _encryptVault(
        Vault(
          vaultId: 'vault-1',
          schemaVersion: 1,
          entries: [_entry('e1', 'Mi banco')],
        ),
        crypto,
      );
      final local = FakeVaultStoragePort()..stored = original;
      final ancestor = FakeVaultStoragePort()..stored = original;
      final state = FakeSyncStatePort();
      await state.saveLastSyncedHash(_hashOf(original));
      final remote = FakeSyncPort();
      return (
        local: local,
        ancestor: ancestor,
        state: state,
        remote: remote,
        useCase: SyncVaultUseCase(
          localStorage: local,
          ancestorStorage: ancestor,
          remote: remote,
          syncState: state,
          crypto: crypto,
          key: _testKey,
          header: _testHeader(),
        ),
      );
    }

    test(
      'remoto cifrado con otra clave → rechazado, nada local cambia',
      () async {
        final crypto = FakeCryptoPort();
        final s = await setUpSynced(crypto);
        final before = (
          s.local.stored,
          s.ancestor.stored,
          await s.state.lastSyncedHash(),
        );
        s.remote.remoteFile = await _encryptVault(
          Vault(vaultId: 'vault-1', schemaVersion: 1),
          crypto,
          key: otherKey,
        );

        await expectLater(
          s.useCase(),
          throwsA(
            isA<RemoteVaultRejectedException>().having(
              (e) => e.reason,
              'reason',
              RemoteVaultRejection.notAuthentic,
            ),
          ),
        );
        expect(s.local.stored, same(before.$1));
        expect(s.ancestor.stored, same(before.$2));
        expect(await s.state.lastSyncedHash(), before.$3);
      },
    );

    test('remoto con bytes basura → rechazado, nada local cambia', () async {
      final s = await setUpSynced(FakeCryptoPort());
      final before = s.local.stored;
      s.remote.remoteFile = _sampleFile(List.filled(64, 7));

      await expectLater(
        s.useCase(),
        throwsA(isA<RemoteVaultRejectedException>()),
      );
      expect(s.local.stored, same(before));
      expect(s.ancestor.stored, same(before));
    });

    test('remoto de otra bóveda (otro vault_id) → rechazado', () async {
      final crypto = FakeCryptoPort();
      final s = await setUpSynced(crypto);
      final before = s.local.stored;
      s.remote.remoteFile = await _encryptVault(
        Vault(vaultId: 'otra-boveda', schemaVersion: 1),
        crypto,
      );

      await expectLater(
        s.useCase(),
        throwsA(
          isA<RemoteVaultRejectedException>().having(
            (e) => e.reason,
            'reason',
            RemoteVaultRejection.differentVault,
          ),
        ),
      );
      expect(s.local.stored, same(before));
    });

    test('también en la rama de merge (cambiaron los dos lados)', () async {
      final crypto = FakeCryptoPort();
      final s = await setUpSynced(crypto);
      final changedLocal = await _encryptVault(
        Vault(
          vaultId: 'vault-1',
          schemaVersion: 1,
          entries: [_entry('e1', 'Mi banco'), _entry('e2', 'Local nueva')],
        ),
        crypto,
      );
      s.local.stored = changedLocal;
      s.remote.remoteFile = await _encryptVault(
        Vault(vaultId: 'vault-1', schemaVersion: 1),
        crypto,
        key: otherKey,
      );

      await expectLater(
        s.useCase(),
        throwsA(isA<RemoteVaultRejectedException>()),
      );
      expect(s.local.stored, same(changedLocal));
    });

    test(
      'sin bóveda local, un remoto no auténtico tampoco se escribe',
      () async {
        final crypto = FakeCryptoPort();
        final local = FakeVaultStoragePort();
        final remote = FakeSyncPort()
          ..remoteFile = await _encryptVault(
            Vault(vaultId: 'vault-1', schemaVersion: 1),
            crypto,
            key: otherKey,
          );

        await expectLater(
          SyncVaultUseCase(
            localStorage: local,
            ancestorStorage: FakeVaultStoragePort(),
            remote: remote,
            syncState: FakeSyncStatePort(),
            crypto: crypto,
            key: _testKey,
            header: _testHeader(),
          ).call(),
          throwsA(isA<RemoteVaultRejectedException>()),
        );
        expect(local.stored, isNull);
      },
    );
  });

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

    test('solo existe remoto (válido) → baja', () async {
      final crypto = FakeCryptoPort();
      final localStorage = FakeVaultStoragePort();
      final remote = FakeSyncPort()
        ..remoteFile = await _encryptVault(
          Vault(vaultId: 'vault-1', schemaVersion: 1),
          crypto,
        );
      final syncState = FakeSyncStatePort();

      final result = await SyncVaultUseCase(
        localStorage: localStorage,
        ancestorStorage: FakeVaultStoragePort(),
        remote: remote,
        syncState: syncState,
        crypto: crypto,
        key: _testKey,
        header: _testHeader(),
      ).call();

      expect(result, isA<SyncDownloaded>());
      expect(localStorage.stored, same(remote.remoteFile));
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

    test(
      'solo cambió el remoto (válido) desde la última sync → baja',
      () async {
        final crypto = FakeCryptoPort();
        final oldFile = _sampleFile([5]);
        final newRemoteFile = await _encryptVault(
          Vault(
            vaultId: 'vault-1',
            schemaVersion: 1,
            entries: [_entry('e1', 'Nueva desde otro dispositivo')],
          ),
          crypto,
        );
        final localStorage = FakeVaultStoragePort()..stored = oldFile;
        final remote = FakeSyncPort()..remoteFile = newRemoteFile;
        final syncState = FakeSyncStatePort();
        await syncState.saveLastSyncedHash(_hashOf(oldFile));

        final result = await SyncVaultUseCase(
          localStorage: localStorage,
          ancestorStorage: FakeVaultStoragePort(),
          remote: remote,
          syncState: syncState,
          crypto: crypto,
          key: _testKey,
          header: _testHeader(),
        ).call();

        expect(result, isA<SyncDownloaded>());
        expect(localStorage.stored, same(newRemoteFile));
      },
    );

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

        await expectLater(
          useCase.call(),
          throwsA(
            isA<AppProblem>().having(
              (e) => e.code,
              'code',
              AppProblemCode.syncNothingToSync,
            ),
          ),
        );
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
        final merged = result as SyncMerged;
        expect(merged.autoResolvedCount, 2);
        expect(merged.fieldConflictsResolved, 0);
        expect(remotePort.remoteFile, isNotNull);
        expect(ancestorStorage.stored, isNotNull);
      },
    );

    test(
      'cambiaron los dos con conflicto real → se resuelve automático (ADR '
      '0009), sin picker: SyncMerged con fieldConflictsResolved > 0, y el '
      'valor perdedor queda en fieldHistory de lo que se sube/guarda',
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
              modifiedAt: DateTime.utc(2026, 3), // más nueva que local
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

        expect(result, isA<SyncMerged>());
        expect((result as SyncMerged).fieldConflictsResolved, 1);
        // Ya se escribió y subió — a diferencia del picker manual viejo,
        // acá nunca queda nada pendiente de una segunda llamada.
        expect(localStorage.stored, isNot(same(localFile)));
        expect(remotePort.remoteFile, isNot(same(remoteFile)));

        final writtenVault = Vault.fromJsonBytes(
          await crypto.decrypt(
            key: _testKey,
            payload: EncryptedPayload(
              nonce: localStorage.stored!.header.nonce,
              ciphertext: localStorage.stored!.encryptedPayload,
            ),
            aad: localStorage.stored!.header.toAadBytes(),
          ),
        );
        final mergedEntry = writtenVault.entries.single;
        expect(
          mergedEntry.title,
          'Editada distinto en remoto',
        ); // ganó el más nuevo
        expect(
          mergedEntry.fieldHistory[titleFieldKey]!.map((r) => r.value),
          contains('Editada en local'),
        );
      },
    );
  });
}
