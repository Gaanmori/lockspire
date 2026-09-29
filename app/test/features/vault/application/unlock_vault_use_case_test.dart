// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Gabriel Ángel Montoya Rico

import 'package:flutter_test/flutter_test.dart';
import 'package:lockspire/features/vault/application/create_vault_use_case.dart';
import 'package:lockspire/features/vault/application/unlock_vault_use_case.dart';
import 'package:lockspire/features/vault/domain/ports/vault_storage_port.dart';

import 'fakes.dart';

void main() {
  group('UnlockVaultUseCase', () {
    test(
      'desbloquea una bóveda creada con la misma contraseña maestra',
      () async {
        final storage = FakeVaultStoragePort();
        final crypto = FakeCryptoPort();
        const masterPassword = 'correcto-caballo-batería-grapa';

        final created = await CreateVaultUseCase(
          storage: storage,
          crypto: crypto,
        )(masterPassword: masterPassword);

        final unlocked = await UnlockVaultUseCase(
          storage: storage,
          crypto: crypto,
        )(masterPassword: masterPassword);

        expect(unlocked.vault.vaultId, created.vault.vaultId);
        expect(unlocked.vault.schemaVersion, created.vault.schemaVersion);
        expect(unlocked.vault.entries, isEmpty);
      },
    );

    test('falla la autenticación si el header fue manipulado (AAD)', () async {
      final storage = FakeVaultStoragePort();
      final crypto = FakeCryptoPort();
      const masterPassword = 'correcto-caballo-batería-grapa';

      await CreateVaultUseCase(storage: storage, crypto: crypto)(
        masterPassword: masterPassword,
      );

      // Simula tamper: cambia un campo del header autenticado como AAD.
      final original = storage.stored!;
      storage.stored = VaultFile(
        header: VaultHeader(
          formatVersion: original.header.formatVersion,
          formatMinReaderVersion: original.header.formatMinReaderVersion,
          salt: original.header.salt,
          nonce: original.header.nonce,
          vaultId: original.header.vaultId,
          createdAt: original.header.createdAt.add(const Duration(days: 1)),
          kdfParams: original.header.kdfParams,
          revision: original.header.revision,
        ),
        encryptedPayload: original.encryptedPayload,
      );

      await expectLater(
        UnlockVaultUseCase(storage: storage, crypto: crypto)(
          masterPassword: masterPassword,
        ),
        throwsA(isA<StateError>()),
      );
    });

    test(
      'subir la revisión en el header rompe la autenticación (ADR 0019)',
      () async {
        final storage = FakeVaultStoragePort();
        final crypto = FakeCryptoPort();
        const masterPassword = 'correcto-caballo-batería-grapa';
        await CreateVaultUseCase(storage: storage, crypto: crypto)(
          masterPassword: masterPassword,
        );

        final original = storage.stored!;
        storage.stored = VaultFile(
          header: original.header.copyWith(
            revision: original.header.revision + 100,
          ),
          encryptedPayload: original.encryptedPayload,
        );

        await expectLater(
          UnlockVaultUseCase(storage: storage, crypto: crypto)(
            masterPassword: masterPassword,
          ),
          throwsA(isA<StateError>()),
        );
      },
    );
  });

  group('UnlockVaultUseCase.unlockFile (Fase 9 — restaurar bóveda)', () {
    test(
      'desbloquea un VaultFile pasado directo, sin pasar por storage.read()',
      () async {
        // Storage separado del que arma el VaultFile — unlockFile no debe
        // tocarlo para nada, confirma que no depende de storage.read().
        final creationStorage = FakeVaultStoragePort();
        final untouchedStorage = FakeVaultStoragePort();
        final crypto = FakeCryptoPort();
        const masterPassword = 'correcto-caballo-batería-grapa';

        await CreateVaultUseCase(storage: creationStorage, crypto: crypto)(
          masterPassword: masterPassword,
        );
        final downloadedFile = creationStorage.stored!;

        final unlocked = await UnlockVaultUseCase(
          storage: untouchedStorage,
          crypto: crypto,
        ).unlockFile(file: downloadedFile, masterPassword: masterPassword);

        expect(unlocked.vault.vaultId, downloadedFile.header.vaultId);
        expect(unlocked.vault.entries, isEmpty);
        expect(untouchedStorage.stored, isNull);
      },
    );

    test('contraseña incorrecta lanza sin escribir nada', () async {
      final creationStorage = FakeVaultStoragePort();
      final crypto = FakeCryptoPort();

      await CreateVaultUseCase(storage: creationStorage, crypto: crypto)(
        masterPassword: 'correcto-caballo-batería-grapa',
      );
      final downloadedFile = creationStorage.stored!;

      await expectLater(
        UnlockVaultUseCase(
          storage: FakeVaultStoragePort(),
          crypto: crypto,
        ).unlockFile(
          file: downloadedFile,
          masterPassword: 'contraseña-incorrecta',
        ),
        throwsA(isA<StateError>()),
      );
    });
  });
}
