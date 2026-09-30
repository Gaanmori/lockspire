// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Gabriel Ángel Montoya Rico

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lockspire/features/sync/presentation/restore_vault_controller.dart';
import 'package:lockspire/features/vault/application/create_vault_use_case.dart';
import 'package:lockspire/features/vault/domain/vault_file_codec.dart';
import 'package:lockspire/features/vault/presentation/providers/vault_auth_attempt_provider.dart';
import 'package:lockspire/features/vault/presentation/vault_session_controller.dart';
import 'package:lockspire/features/vault/presentation/vault_session_state.dart';
import '../../../support/fakes/vault_fakes.dart';

import 'vault_session_harness.dart';

void main() {
  group('VaultSessionController — restaurar bóveda existente (Fase 9)', () {
    test('desbloquea un VaultFile descargado y lo siembra como bóveda local, '
        'ancestro y hash de sync (para que la próxima sync dé SyncUpToDate, '
        'no un conflicto falso)', () async {
      final built = buildSessionContainerWithSync();
      final container = built.container;
      await container.read(vaultSessionControllerProvider.future);

      // Simula un VaultFile ya "descargado" de otro dispositivo — creado
      // con la misma contraseña maestra, en un storage aparte que nunca
      // toca el controller.
      final remoteStorage = FakeVaultStoragePort();
      await CreateVaultUseCase(
        storage: remoteStorage,
        crypto: built.fakes.crypto,
      )(masterPassword: masterPassword);
      final downloadedFile = remoteStorage.stored!;

      await container
          .read(restoreVaultControllerProvider)
          .restore(file: downloadedFile, masterPassword: masterPassword);

      expect(
        container.read(vaultSessionControllerProvider).value,
        isA<VaultSessionUnlocked>(),
      );
      expect(built.fakes.storage.stored, downloadedFile);
      expect(built.fakes.ancestorStorage.stored, downloadedFile);
      expect(
        await built.fakes.syncState.lastSyncedHash(),
        VaultFileCodec.sha256Hex(downloadedFile),
      );
      expect(container.read(vaultAuthAttemptProvider).hasError, isFalse);
    });

    test('contraseña incorrecta: no escribe nada localmente, el error queda '
        'en vaultAuthAttemptProvider y la sesión sigue sin bóveda', () async {
      final built = buildSessionContainerWithSync();
      final container = built.container;
      await container.read(vaultSessionControllerProvider.future);

      final remoteStorage = FakeVaultStoragePort();
      await CreateVaultUseCase(
        storage: remoteStorage,
        crypto: built.fakes.crypto,
      )(masterPassword: masterPassword);
      final downloadedFile = remoteStorage.stored!;

      await container
          .read(restoreVaultControllerProvider)
          .restore(
            file: downloadedFile,
            masterPassword: 'contraseña-incorrecta',
          );

      expect(
        container.read(vaultSessionControllerProvider).value,
        isA<VaultSessionNoVault>(),
      );
      expect(built.fakes.storage.stored, isNull);
      expect(built.fakes.ancestorStorage.stored, isNull);
      expect(container.read(vaultAuthAttemptProvider).hasError, isTrue);
    });
  });
}
