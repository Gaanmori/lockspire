// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Lockspire

import 'package:flutter_test/flutter_test.dart';
import 'package:lockspire/features/vault/application/create_vault_use_case.dart';

import 'fakes.dart';

void main() {
  group('CreateVaultUseCase', () {
    test('crea una bóveda vacía y la persiste cifrada en el storage', () async {
      final storage = FakeVaultStoragePort();
      final crypto = FakeCryptoPort();
      final useCase = CreateVaultUseCase(storage: storage, crypto: crypto);

      final result = await useCase(
        masterPassword: 'correcto-caballo-batería-grapa',
      );
      final vault = result.vault;

      expect(vault.schemaVersion, 1);
      expect(vault.entries, isEmpty);
      expect(vault.folders, isEmpty);
      expect(vault.vaultId, isNotEmpty);

      final stored = storage.stored;
      expect(stored, isNotNull);
      expect(stored!.header.vaultId, vault.vaultId);
      expect(stored.header.kdfParams.memoryKib, defaultArgon2Params.memoryKib);
      // El payload guardado no debe contener el texto plano del vaultId.
      expect(
        String.fromCharCodes(stored.encryptedPayload),
        isNot(contains(vault.vaultId)),
      );
    });
  });
}
