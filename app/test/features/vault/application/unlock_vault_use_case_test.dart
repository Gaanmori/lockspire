// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Lockspire

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

        expect(unlocked.vaultId, created.vaultId);
        expect(unlocked.schemaVersion, created.schemaVersion);
        expect(unlocked.entries, isEmpty);
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
  });
}
