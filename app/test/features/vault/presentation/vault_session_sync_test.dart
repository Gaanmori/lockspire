// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Gabriel Ángel Montoya Rico

import 'package:flutter_test/flutter_test.dart';
import 'package:lockspire/features/sync/application/sync_vault_use_case.dart';
import 'package:lockspire/features/sync/presentation/sync_controller.dart';
import 'package:lockspire/features/vault/presentation/vault_entries_controller.dart';
import 'package:lockspire/features/vault/presentation/vault_session_controller.dart';

import 'vault_session_harness.dart';

void main() {
  group('VaultSessionController — sync automática (Fase 7)', () {
    test(
      'crear la bóveda con credenciales configuradas dispara sync sola',
      () => withFakeClock((clock, settle) {
        final built = buildSessionContainerWithSync();
        final container = built.container;
        final notifier = container.read(
          vaultSessionControllerProvider.notifier,
        );
        settle(container.read(vaultSessionControllerProvider.future));

        settle(notifier.createVault(masterPassword));
        // El trigger es fire-and-forget (unawaited) — se le da margen.
        clock.elapse(shortTimeout * 3);

        expect(built.fakes.syncPort.remoteFile, isNotNull);
        expect(
          container.read(syncControllerProvider).value,
          isA<SyncUploaded>(),
        );
      }),
    );

    test(
      'sin credenciales configuradas, no dispara nada',
      () => withFakeClock((clock, settle) {
        final built = buildSessionContainerWithSync(hasCredentials: false);
        final container = built.container;
        final notifier = container.read(
          vaultSessionControllerProvider.notifier,
        );
        settle(container.read(vaultSessionControllerProvider.future));

        settle(notifier.createVault(masterPassword));
        clock.elapse(shortTimeout * 3);

        expect(built.fakes.syncPort.remoteFile, isNull);
        expect(container.read(syncControllerProvider).value, isNull);
      }),
    );

    test(
      'varios guardados seguidos disparan una sola sync (debounce)',
      () => withFakeClock((clock, settle) {
        final built = buildSessionContainerWithSync();
        final container = built.container;
        final notifier = container.read(
          vaultSessionControllerProvider.notifier,
        );
        settle(container.read(vaultSessionControllerProvider.future));

        settle(notifier.createVault(masterPassword));
        // Deja asentar el auto-sync propio de createVault() antes de medir.
        clock.elapse(shortTimeout * 3);
        final callsAfterCreate = built.fakes.syncPort.uploadVaultCalls;

        settle(
          container.read(vaultEntriesControllerProvider).addEntry(title: 'A'),
        );
        settle(
          container.read(vaultEntriesControllerProvider).addEntry(title: 'B'),
        );
        // Las dos quedan dentro de la misma ventana de debounce — solo
        // debería correr una sync, no dos.
        clock.elapse(shortTimeout * 3);

        expect(built.fakes.syncPort.uploadVaultCalls, callsAfterCreate + 1);
      }),
    );
  });
}
