// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Gabriel Ángel Montoya Rico

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:lockspire/features/vault/application/create_vault_use_case.dart';
import 'package:lockspire/features/vault/application/save_vault_use_case.dart';
import 'package:lockspire/features/vault/application/unlock_vault_use_case.dart';
import 'package:lockspire/features/vault/domain/entities/vault_entry.dart';
import 'package:lockspire/features/vault/domain/ports/vault_storage_port.dart';

import 'fakes.dart';

const _masterPassword = 'correcto-caballo-batería-grapa';

void main() {
  group('SaveVaultUseCase', () {
    test('guarda cambios, reusa el header existente (mismo salt/vaultId/kdf) '
        'y lo que se guarda se puede releer', () async {
      final storage = FakeVaultStoragePort();
      final crypto = FakeCryptoPort();
      final created = await CreateVaultUseCase(
        storage: storage,
        crypto: crypto,
      )(masterPassword: _masterPassword);
      final payloadBeforeSave = storage.stored!.encryptedPayload;

      final entry = VaultEntry.create(
        title: 'Ejemplo',
        fields: {'username': 'gaan'},
      );
      final updatedVault = created.vault.copyWith(entries: [entry]);

      final written = await SaveVaultUseCase(storage: storage, crypto: crypto)
          .call(
            vault: updatedVault,
            key: created.key,
            header: created.header,
            expectedFileHash: created.fileHash,
          );

      expect(written.header.salt, created.header.salt);
      expect(written.header.vaultId, created.header.vaultId);
      expect(
        written.header.kdfParams.memoryKib,
        created.header.kdfParams.memoryKib,
      );
      // El contenido cambió (se agregó una entrada), así que el payload
      // cifrado también — aunque `FakeCryptoPort.encrypt()` use un nonce
      // fijo (a diferencia de la implementación real, que lo aleatoriza en
      // cada llamada).
      expect(written.encryptedPayload, isNot(payloadBeforeSave));

      final reunlocked = await UnlockVaultUseCase(
        storage: storage,
        crypto: crypto,
      )(masterPassword: _masterPassword);

      expect(reunlocked.vault.entries, hasLength(1));
      expect(reunlocked.vault.entries.first.title, 'Ejemplo');
      expect(reunlocked.vault.entries.first.fields['username'], 'gaan');
    });

    test(
      'hash no coincide con lo que hay en disco -> VaultWriteConflictException, '
      'no escribe nada',
      () async {
        final storage = FakeVaultStoragePort();
        final crypto = FakeCryptoPort();
        final created = await CreateVaultUseCase(
          storage: storage,
          crypto: crypto,
        )(masterPassword: _masterPassword);

        // Simula que el archivo cambió en disco por fuera de esta sesión
        // (ej. otro dispositivo sincronizó una versión más nueva).
        final externallyChanged = VaultFile(
          header: created.header,
          encryptedPayload: Uint8List.fromList([9, 9, 9]),
        );
        storage.stored = externallyChanged;

        await expectLater(
          SaveVaultUseCase(storage: storage, crypto: crypto).call(
            vault: created.vault,
            key: created.key,
            header: created.header,
            expectedFileHash: created.fileHash, // desactualizado a propósito
          ),
          throwsA(isA<VaultWriteConflictException>()),
        );

        // No se sobrescribió lo que había cambiado por fuera.
        expect(storage.stored, same(externallyChanged));
      },
    );
  });
}
