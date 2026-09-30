// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Gabriel Ángel Montoya Rico

import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:lockspire/features/vault/application/save_vault_use_case.dart';
import 'package:lockspire/features/vault/domain/entities/vault_entry.dart';
import 'package:lockspire/features/vault/presentation/vault_entries_controller.dart';
import 'package:lockspire/features/vault/presentation/vault_session_controller.dart';
import 'package:lockspire/features/vault/presentation/vault_session_state.dart';

import 'vault_session_harness.dart';

void main() {
  group('VaultSessionController — gestión de entradas (Fase 5)', () {
    test('addEntry() persiste y aparece en el estado', () async {
      final built = buildSessionContainer(timeout: const Duration(minutes: 5));
      final container = built.container;
      final notifier = container.read(vaultSessionControllerProvider.notifier);
      await container.read(vaultSessionControllerProvider.future);
      await notifier.createVault(masterPassword);

      await container
          .read(vaultEntriesControllerProvider)
          .addEntry(
            title: 'Ejemplo',
            fields: {'username': 'gaan', 'password': 'correcto-caballo'},
          );

      final state =
          container.read(vaultSessionControllerProvider).value
              as VaultSessionUnlocked;
      expect(state.vault.entries, hasLength(1));
      expect(state.vault.entries.first.title, 'Ejemplo');
      expect(state.vault.entries.first.fields['username'], 'gaan');
    });

    test('importEntries() agrega varias entradas de una vez, sin perder lo '
        'que ya había', () async {
      final built = buildSessionContainer(timeout: const Duration(minutes: 5));
      final container = built.container;
      final notifier = container.read(vaultSessionControllerProvider.notifier);
      await container.read(vaultSessionControllerProvider.future);
      await notifier.createVault(masterPassword);
      await container
          .read(vaultEntriesControllerProvider)
          .addEntry(title: 'Ya existía', fields: {});

      await container.read(vaultEntriesControllerProvider).importEntries([
        VaultEntry.create(title: 'Importada 1', fields: {'username': 'a'}),
        VaultEntry.create(title: 'Importada 2', fields: {'username': 'b'}),
      ]);

      final state =
          container.read(vaultSessionControllerProvider).value
              as VaultSessionUnlocked;
      expect(state.vault.entries, hasLength(3));
      expect(
        state.vault.entries.map((e) => e.title),
        containsAll(['Ya existía', 'Importada 1', 'Importada 2']),
      );
    });

    test(
      'updateEntry() edita título y campos sin duplicar la entrada',
      () async {
        final built = buildSessionContainer(
          timeout: const Duration(minutes: 5),
        );
        final container = built.container;
        final notifier = container.read(
          vaultSessionControllerProvider.notifier,
        );
        await container.read(vaultSessionControllerProvider.future);
        await notifier.createVault(masterPassword);
        await container
            .read(vaultEntriesControllerProvider)
            .addEntry(title: 'Original', fields: {'username': 'a'});

        final id =
            (container.read(vaultSessionControllerProvider).value
                    as VaultSessionUnlocked)
                .vault
                .entries
                .first
                .id;

        await container
            .read(vaultEntriesControllerProvider)
            .updateEntry(id: id, title: 'Editado', fields: {'username': 'b'});

        final state =
            container.read(vaultSessionControllerProvider).value
                as VaultSessionUnlocked;
        expect(state.vault.entries, hasLength(1));
        expect(state.vault.entries.first.title, 'Editado');
        expect(state.vault.entries.first.fields['username'], 'b');
      },
    );

    test(
      'deleteEntry() marca deleted (tombstone) sin borrar de la lista',
      () async {
        final built = buildSessionContainer(
          timeout: const Duration(minutes: 5),
        );
        final container = built.container;
        final notifier = container.read(
          vaultSessionControllerProvider.notifier,
        );
        await container.read(vaultSessionControllerProvider.future);
        await notifier.createVault(masterPassword);
        await container
            .read(vaultEntriesControllerProvider)
            .addEntry(title: 'Para borrar');

        final id =
            (container.read(vaultSessionControllerProvider).value
                    as VaultSessionUnlocked)
                .vault
                .entries
                .first
                .id;

        await container.read(vaultEntriesControllerProvider).deleteEntry(id);

        final state =
            container.read(vaultSessionControllerProvider).value
                as VaultSessionUnlocked;
        expect(state.vault.entries, hasLength(1));
        expect(state.vault.entries.first.deleted, isTrue);
        expect(state.vault.entries.first.deletedAt, isNotNull);
      },
    );

    test('agregar/editar/borrar no vuelven a derivar la clave (no piden la '
        'contraseña maestra de nuevo)', () async {
      final built = buildSessionContainer(timeout: const Duration(minutes: 5));
      final container = built.container;
      final notifier = container.read(vaultSessionControllerProvider.notifier);
      await container.read(vaultSessionControllerProvider.future);
      await notifier.createVault(masterPassword);

      final callsAfterCreate = built.fakes.crypto.deriveKeyCalls;
      expect(callsAfterCreate, 1);

      await container.read(vaultEntriesControllerProvider).addEntry(title: 'A');
      final id =
          (container.read(vaultSessionControllerProvider).value
                  as VaultSessionUnlocked)
              .vault
              .entries
              .first
              .id;
      await container
          .read(vaultEntriesControllerProvider)
          .updateEntry(id: id, title: 'A editado', fields: {});
      await container.read(vaultEntriesControllerProvider).deleteEntry(id);

      expect(built.fakes.crypto.deriveKeyCalls, callsAfterCreate);
    });

    test('guardar cuando el archivo cambió por fuera de la sesión (ej. otro '
        'dispositivo sincronizó): recarga con la key ya retenida, sin pedir '
        'la contraseña maestra, y aplica el cambio sobre esa versión: '
        'quedan los dos (P1)', () async {
      final built = buildSessionContainer(timeout: const Duration(minutes: 5));
      final container = built.container;
      final notifier = container.read(vaultSessionControllerProvider.notifier);
      await container.read(vaultSessionControllerProvider.future);
      await notifier.createVault(masterPassword);

      final stateBefore =
          container.read(vaultSessionControllerProvider).value
              as VaultSessionUnlocked;
      expect(built.fakes.crypto.deriveKeyCalls, 1);

      // Simula otro dispositivo/sesión escribiendo un cambio con la misma
      // key — directo contra el storage, sin pasar por este controller.
      final externalEntry = VaultEntry.create(title: 'Desde otro dispositivo');
      await SaveVaultUseCase(
        storage: built.fakes.storage,
        crypto: built.fakes.crypto,
      ).call(
        vault: stateBefore.vault.copyWith(entries: [externalEntry]),
        key: stateBefore.key,
        header: stateBefore.header,
        expectedFileHash: stateBefore.fileHash,
      );

      // Esta sesión sigue con el estado viejo en memoria (no sabe del
      // cambio externo) e intenta guardar algo propio.
      await container
          .read(vaultEntriesControllerProvider)
          .addEntry(title: 'Guardada acá');

      final after =
          container.read(vaultSessionControllerProvider).value
              as VaultSessionUnlocked;
      expect(after.vault.entries.map((e) => e.title), [
        'Desde otro dispositivo',
        'Guardada acá',
      ]);
      // No volvió a derivar: se recargó con la key ya retenida.
      expect(built.fakes.crypto.deriveKeyCalls, 1);
    });

    test('dos cambios a la vez (editar mientras la extensión guarda) quedan '
        'los dos (P1)', () async {
      final built = buildSessionContainer(timeout: const Duration(minutes: 5));
      final container = built.container;
      final notifier = container.read(vaultSessionControllerProvider.notifier);
      await container.read(vaultSessionControllerProvider.future);
      await notifier.createVault(masterPassword);
      final entries = container.read(vaultEntriesControllerProvider);

      await Future.wait([
        entries.addEntry(title: 'Del usuario'),
        entries.addEntry(title: 'Del navegador'),
        notifier.reloadFromDisk(),
      ]);

      final state =
          container.read(vaultSessionControllerProvider).value
              as VaultSessionUnlocked;
      expect(state.vault.entries.map((e) => e.title), [
        'Del usuario',
        'Del navegador',
      ]);
      // Y lo mismo quedó en disco.
      await notifier.reloadFromDisk();
      expect(
        (container.read(vaultSessionControllerProvider).value
                as VaultSessionUnlocked)
            .vault
            .entries
            .length,
        2,
      );
    });

    test('bloquear mientras se escribe no vuelve a abrir la bóveda al '
        'terminar', () async {
      final built = buildSessionContainer(timeout: const Duration(minutes: 5));
      final container = built.container;
      final notifier = container.read(vaultSessionControllerProvider.notifier);
      await container.read(vaultSessionControllerProvider.future);
      await notifier.createVault(masterPassword);

      final gate = built.fakes.storage.writeGate = Completer<void>();
      final saving = container
          .read(vaultEntriesControllerProvider)
          .addEntry(title: 'Lenta');
      await pumpEventQueue();
      notifier.lock();
      gate.complete();
      await saving;

      expect(
        container.read(vaultSessionControllerProvider).value,
        isA<VaultSessionLocked>(),
      );
    });

    test('reloadFromDisk() refresca la sesión con lo que haya en disco, sin '
        'volver a derivar la clave', () async {
      final built = buildSessionContainer(timeout: const Duration(minutes: 5));
      final container = built.container;
      final notifier = container.read(vaultSessionControllerProvider.notifier);
      await container.read(vaultSessionControllerProvider.future);
      await notifier.createVault(masterPassword);

      final stateBefore =
          container.read(vaultSessionControllerProvider).value
              as VaultSessionUnlocked;
      final externalEntry = VaultEntry.create(title: 'Escrita por fuera');
      await SaveVaultUseCase(
        storage: built.fakes.storage,
        crypto: built.fakes.crypto,
      ).call(
        vault: stateBefore.vault.copyWith(entries: [externalEntry]),
        key: stateBefore.key,
        header: stateBefore.header,
        expectedFileHash: stateBefore.fileHash,
      );

      await notifier.reloadFromDisk();

      final state =
          container.read(vaultSessionControllerProvider).value
              as VaultSessionUnlocked;
      expect(
        state.vault.entries.map((e) => e.title),
        contains('Escrita por fuera'),
      );
      expect(state.fileHash, isNot(stateBefore.fileHash));
      expect(built.fakes.crypto.deriveKeyCalls, 1);
    });
  });
}
