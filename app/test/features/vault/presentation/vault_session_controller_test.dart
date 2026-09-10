// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Lockspire

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lockspire/features/sync/application/sync_vault_use_case.dart';
import 'package:lockspire/features/sync/presentation/providers/active_sync_port_provider.dart';
import 'package:lockspire/features/sync/presentation/providers/is_sync_configured_provider.dart';
import 'package:lockspire/features/sync/presentation/providers/sync_ancestor_storage_port_provider.dart';
import 'package:lockspire/features/sync/presentation/providers/sync_state_port_provider.dart';
import 'package:lockspire/features/sync/presentation/sync_controller.dart';
import 'package:lockspire/features/vault/application/create_vault_use_case.dart';
import 'package:lockspire/features/vault/application/save_vault_use_case.dart';
import 'package:lockspire/features/vault/domain/entities/vault_entry.dart';
import 'package:lockspire/features/vault/domain/vault_file_codec.dart';
import 'package:lockspire/features/vault/presentation/providers/auto_lock_timeout_provider.dart';
import 'package:lockspire/features/vault/presentation/providers/auto_sync_debounce_provider.dart';
import 'package:lockspire/features/vault/presentation/providers/crypto_port_provider.dart';
import 'package:lockspire/features/vault/presentation/providers/vault_auth_attempt_provider.dart';
import 'package:lockspire/features/vault/presentation/providers/vault_storage_port_provider.dart';
import 'package:lockspire/features/vault/presentation/vault_session_controller.dart';
import 'package:lockspire/features/vault/presentation/vault_session_state.dart';

import '../../sync/application/fakes.dart' as sync_fakes;
import '../application/fakes.dart';

// Duración corta para no esperar minutos reales en los tests — usa Timer
// real, así que hay margen inherente de timing (ver docs/STATE.md, nota
// de la Fase 3: si aparece flakiness intermitente, migrar a fake_async).
const _shortTimeout = Duration(milliseconds: 60);
const _masterPassword = 'correcto-caballo-batería-grapa';

class _TestFakes {
  final FakeCryptoPort crypto;
  final FakeVaultStoragePort storage;

  _TestFakes({required this.crypto, required this.storage});
}

({ProviderContainer container, _TestFakes fakes}) _buildContainer({
  Duration timeout = _shortTimeout,
}) {
  final crypto = FakeCryptoPort();
  final storage = FakeVaultStoragePort();
  final container = ProviderContainer(
    overrides: [
      cryptoPortProvider.overrideWith((ref) async => crypto),
      vaultStoragePortProvider.overrideWith((ref) async => storage),
      autoLockTimeoutProvider.overrideWith((ref) => timeout),
    ],
  );
  addTearDown(container.dispose);
  return (
    container: container,
    fakes: _TestFakes(crypto: crypto, storage: storage),
  );
}

class _SyncTestFakes {
  final FakeCryptoPort crypto;
  final FakeVaultStoragePort storage;
  final FakeVaultStoragePort ancestorStorage;
  final sync_fakes.FakeSyncPort syncPort;
  final sync_fakes.FakeSyncStatePort syncState;

  _SyncTestFakes({
    required this.crypto,
    required this.storage,
    required this.ancestorStorage,
    required this.syncPort,
    required this.syncState,
  });
}

/// Igual que [_buildContainer], pero con credenciales de sync configuradas
/// y todo el resto de las dependencias de `SyncVaultUseCase` fakeadas —
/// para los tests de sync automática de más abajo. [hasCredentials] en
/// `false` simula que el usuario nunca configuró sync.
({ProviderContainer container, _SyncTestFakes fakes}) _buildContainerWithSync({
  Duration timeout = const Duration(minutes: 5),
  Duration syncDebounce = _shortTimeout,
  bool hasCredentials = true,
}) {
  final crypto = FakeCryptoPort();
  final storage = FakeVaultStoragePort();
  final ancestorStorage = FakeVaultStoragePort();
  final syncPort = sync_fakes.FakeSyncPort();
  final syncState = sync_fakes.FakeSyncStatePort();

  final container = ProviderContainer(
    overrides: [
      cryptoPortProvider.overrideWith((ref) async => crypto),
      vaultStoragePortProvider.overrideWith((ref) async => storage),
      autoLockTimeoutProvider.overrideWith((ref) => timeout),
      autoSyncDebounceProvider.overrideWith((ref) => syncDebounce),
      isSyncConfiguredProvider.overrideWith((ref) async => hasCredentials),
      activeSyncPortProvider.overrideWith((ref) async => syncPort),
      syncStatePortProvider.overrideWith((ref) => syncState),
      syncAncestorStoragePortProvider.overrideWith(
        (ref) async => ancestorStorage,
      ),
    ],
  );
  addTearDown(container.dispose);
  return (
    container: container,
    fakes: _SyncTestFakes(
      crypto: crypto,
      storage: storage,
      ancestorStorage: ancestorStorage,
      syncPort: syncPort,
      syncState: syncState,
    ),
  );
}

void main() {
  group('VaultSessionController — auto-lock (ADR 0008)', () {
    test(
      'bloquea automáticamente al superar el timeout de inactividad',
      () async {
        final built = _buildContainer();
        final container = built.container;
        final notifier = container.read(
          vaultSessionControllerProvider.notifier,
        );
        await container.read(vaultSessionControllerProvider.future);
        await notifier.createVault(_masterPassword);

        expect(
          container.read(vaultSessionControllerProvider).value,
          isA<VaultSessionUnlocked>(),
        );

        await Future<void>.delayed(_shortTimeout * 3);

        expect(
          container.read(vaultSessionControllerProvider).value,
          isA<VaultSessionLocked>(),
        );
      },
    );

    test('registerActivity() reinicia el timer y evita el bloqueo', () async {
      final built = _buildContainer();
      final container = built.container;
      final notifier = container.read(vaultSessionControllerProvider.notifier);
      await container.read(vaultSessionControllerProvider.future);
      await notifier.createVault(_masterPassword);

      // A mitad del timeout original se registra actividad -> se reinicia.
      await Future<void>.delayed(_shortTimeout ~/ 2);
      notifier.registerActivity();
      await Future<void>.delayed(
        _shortTimeout ~/ 2 + const Duration(milliseconds: 15),
      );

      // Ya pasó el timeout ORIGINAL, pero como se reinició, sigue desbloqueada.
      expect(
        container.read(vaultSessionControllerProvider).value,
        isA<VaultSessionUnlocked>(),
      );

      // Tras el nuevo timeout completo (desde el reinicio), sí se bloquea.
      await Future<void>.delayed(_shortTimeout);
      expect(
        container.read(vaultSessionControllerProvider).value,
        isA<VaultSessionLocked>(),
      );
    });

    test(
      'onAppLifecycleChanged(paused) bloquea inmediatamente, sin esperar el timer',
      () async {
        final built = _buildContainer(timeout: const Duration(minutes: 5));
        final container = built.container;
        final notifier = container.read(
          vaultSessionControllerProvider.notifier,
        );
        await container.read(vaultSessionControllerProvider.future);
        await notifier.createVault(_masterPassword);

        notifier.onAppLifecycleChanged(AppLifecycleState.paused);

        expect(
          container.read(vaultSessionControllerProvider).value,
          isA<VaultSessionLocked>(),
        );
      },
    );

    test(
      'onAppLifecycleChanged(inactive) NO bloquea (se ignora a propósito)',
      () async {
        final built = _buildContainer(timeout: const Duration(minutes: 5));
        final container = built.container;
        final notifier = container.read(
          vaultSessionControllerProvider.notifier,
        );
        await container.read(vaultSessionControllerProvider.future);
        await notifier.createVault(_masterPassword);

        notifier.onAppLifecycleChanged(AppLifecycleState.inactive);

        expect(
          container.read(vaultSessionControllerProvider).value,
          isA<VaultSessionUnlocked>(),
        );
      },
    );

    test('registerActivity() y onAppLifecycleChanged() durante el await de '
        'createVault()/unlock() no lanzan excepción — y el estado de sesión '
        '(a diferencia de vaultAuthAttemptProvider) ni se entera de que hay '
        'un intento en curso, ver vault_auth_attempt_provider.dart', () async {
      final built = _buildContainer(timeout: const Duration(minutes: 5));
      final container = built.container;
      final notifier = container.read(vaultSessionControllerProvider.notifier);
      await container.read(vaultSessionControllerProvider.future);

      // No se espera el Future — se dispara actividad/lifecycle mientras
      // sigue pendiente, exactamente la ventana de los ~3.5s de Argon2id.
      final createFuture = notifier.createVault(_masterPassword);

      // El estado de sesión sigue siendo el de antes de empezar — no pasa
      // por AsyncLoading, así que .value nunca es null durante este
      // intento (el progreso vive aparte, en vaultAuthAttemptProvider).
      expect(
        container.read(vaultSessionControllerProvider).value,
        isA<VaultSessionNoVault>(),
      );
      expect(container.read(vaultAuthAttemptProvider).isLoading, isTrue);

      expect(() => notifier.registerActivity(), returnsNormally);
      expect(
        () => notifier.onAppLifecycleChanged(AppLifecycleState.paused),
        returnsNormally,
      );

      await createFuture;
      expect(
        container.read(vaultSessionControllerProvider).value,
        isA<VaultSessionUnlocked>(),
      );
      expect(container.read(vaultAuthAttemptProvider).hasError, isFalse);
    });

    test('contraseña incorrecta: el error queda en vaultAuthAttemptProvider, '
        'el estado de sesión sigue Locked (no se vuelve un error genérico '
        'que reemplace la pantalla completa)', () async {
      final built = _buildContainer(timeout: const Duration(minutes: 5));
      final container = built.container;
      final notifier = container.read(vaultSessionControllerProvider.notifier);
      await container.read(vaultSessionControllerProvider.future);
      await notifier.createVault(_masterPassword);
      notifier.lock();

      await notifier.unlock('contraseña-incorrecta');

      expect(
        container.read(vaultSessionControllerProvider).value,
        isA<VaultSessionLocked>(),
      );
      expect(container.read(vaultAuthAttemptProvider).hasError, isTrue);
    });
  });

  group('VaultSessionController — gestión de entradas (Fase 5)', () {
    test('addEntry() persiste y aparece en el estado', () async {
      final built = _buildContainer(timeout: const Duration(minutes: 5));
      final container = built.container;
      final notifier = container.read(vaultSessionControllerProvider.notifier);
      await container.read(vaultSessionControllerProvider.future);
      await notifier.createVault(_masterPassword);

      await notifier.addEntry(
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
      final built = _buildContainer(timeout: const Duration(minutes: 5));
      final container = built.container;
      final notifier = container.read(vaultSessionControllerProvider.notifier);
      await container.read(vaultSessionControllerProvider.future);
      await notifier.createVault(_masterPassword);
      await notifier.addEntry(title: 'Ya existía', fields: {});

      await notifier.importEntries([
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
        final built = _buildContainer(timeout: const Duration(minutes: 5));
        final container = built.container;
        final notifier = container.read(
          vaultSessionControllerProvider.notifier,
        );
        await container.read(vaultSessionControllerProvider.future);
        await notifier.createVault(_masterPassword);
        await notifier.addEntry(title: 'Original', fields: {'username': 'a'});

        final id =
            (container.read(vaultSessionControllerProvider).value
                    as VaultSessionUnlocked)
                .vault
                .entries
                .first
                .id;

        await notifier.updateEntry(
          id: id,
          title: 'Editado',
          fields: {'username': 'b'},
        );

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
        final built = _buildContainer(timeout: const Duration(minutes: 5));
        final container = built.container;
        final notifier = container.read(
          vaultSessionControllerProvider.notifier,
        );
        await container.read(vaultSessionControllerProvider.future);
        await notifier.createVault(_masterPassword);
        await notifier.addEntry(title: 'Para borrar');

        final id =
            (container.read(vaultSessionControllerProvider).value
                    as VaultSessionUnlocked)
                .vault
                .entries
                .first
                .id;

        await notifier.deleteEntry(id);

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
      final built = _buildContainer(timeout: const Duration(minutes: 5));
      final container = built.container;
      final notifier = container.read(vaultSessionControllerProvider.notifier);
      await container.read(vaultSessionControllerProvider.future);
      await notifier.createVault(_masterPassword);

      final callsAfterCreate = built.fakes.crypto.deriveKeyCalls;
      expect(callsAfterCreate, 1);

      await notifier.addEntry(title: 'A');
      final id =
          (container.read(vaultSessionControllerProvider).value
                  as VaultSessionUnlocked)
              .vault
              .entries
              .first
              .id;
      await notifier.updateEntry(id: id, title: 'A editado', fields: {});
      await notifier.deleteEntry(id);

      expect(built.fakes.crypto.deriveKeyCalls, callsAfterCreate);
    });

    test('guardar cuando el archivo cambió por fuera de la sesión (ej. otro '
        'dispositivo sincronizó): falla explícito, recarga el estado con la '
        'key ya retenida (sin pedir la contraseña maestra de nuevo) y no '
        'pierde lo que se había guardado por fuera', () async {
      final built = _buildContainer(timeout: const Duration(minutes: 5));
      final container = built.container;
      final notifier = container.read(vaultSessionControllerProvider.notifier);
      await container.read(vaultSessionControllerProvider.future);
      await notifier.createVault(_masterPassword);

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
      await expectLater(
        notifier.addEntry(title: 'Se pierde el intento'),
        throwsA(isA<VaultWriteConflictException>()),
      );

      final recovered =
          container.read(vaultSessionControllerProvider).value
              as VaultSessionUnlocked;
      expect(recovered.fileHash, isNot(stateBefore.fileHash));
      expect(
        recovered.vault.entries.map((e) => e.title),
        contains('Desde otro dispositivo'),
      );
      // No volvió a derivar: se recargó con la key ya retenida.
      expect(built.fakes.crypto.deriveKeyCalls, 1);
    });

    test('reloadFromDisk() refresca la sesión con lo que haya en disco, sin '
        'volver a derivar la clave', () async {
      final built = _buildContainer(timeout: const Duration(minutes: 5));
      final container = built.container;
      final notifier = container.read(vaultSessionControllerProvider.notifier);
      await container.read(vaultSessionControllerProvider.future);
      await notifier.createVault(_masterPassword);

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

  group('VaultSessionController — sync automática (Fase 7)', () {
    test(
      'crear la bóveda con credenciales configuradas dispara sync sola',
      () async {
        final built = _buildContainerWithSync();
        final container = built.container;
        final notifier = container.read(
          vaultSessionControllerProvider.notifier,
        );
        await container.read(vaultSessionControllerProvider.future);

        await notifier.createVault(_masterPassword);
        // El trigger es fire-and-forget (unawaited) — se le da margen.
        await Future<void>.delayed(_shortTimeout * 3);

        expect(built.fakes.syncPort.remoteFile, isNotNull);
        expect(
          container.read(syncControllerProvider).value,
          isA<SyncUploaded>(),
        );
      },
    );

    test('sin credenciales configuradas, no dispara nada', () async {
      final built = _buildContainerWithSync(hasCredentials: false);
      final container = built.container;
      final notifier = container.read(vaultSessionControllerProvider.notifier);
      await container.read(vaultSessionControllerProvider.future);

      await notifier.createVault(_masterPassword);
      await Future<void>.delayed(_shortTimeout * 3);

      expect(built.fakes.syncPort.remoteFile, isNull);
      expect(container.read(syncControllerProvider).value, isNull);
    });

    test(
      'varios guardados seguidos disparan una sola sync (debounce)',
      () async {
        final built = _buildContainerWithSync();
        final container = built.container;
        final notifier = container.read(
          vaultSessionControllerProvider.notifier,
        );
        await container.read(vaultSessionControllerProvider.future);

        await notifier.createVault(_masterPassword);
        // Deja asentar el auto-sync propio de createVault() antes de medir.
        await Future<void>.delayed(_shortTimeout * 3);
        final callsAfterCreate = built.fakes.syncPort.uploadVaultCalls;

        await notifier.addEntry(title: 'A');
        await notifier.addEntry(title: 'B');
        // Las dos quedan dentro de la misma ventana de debounce — solo
        // debería correr una sync, no dos.
        await Future<void>.delayed(_shortTimeout * 3);

        expect(built.fakes.syncPort.uploadVaultCalls, callsAfterCreate + 1);
      },
    );
  });

  group('VaultSessionController — restaurar bóveda existente (Fase 9)', () {
    test(
      'desbloquea un VaultFile descargado y lo siembra como bóveda local, '
      'ancestro y hash de sync (para que la próxima sync dé SyncUpToDate, '
      'no un conflicto falso)',
      () async {
        final built = _buildContainerWithSync();
        final container = built.container;
        final notifier = container.read(
          vaultSessionControllerProvider.notifier,
        );
        await container.read(vaultSessionControllerProvider.future);

        // Simula un VaultFile ya "descargado" de otro dispositivo — creado
        // con la misma contraseña maestra, en un storage aparte que nunca
        // toca el controller.
        final remoteStorage = FakeVaultStoragePort();
        await CreateVaultUseCase(
          storage: remoteStorage,
          crypto: built.fakes.crypto,
        )(masterPassword: _masterPassword);
        final downloadedFile = remoteStorage.stored!;

        await notifier.restoreFromDownloadedFile(
          file: downloadedFile,
          masterPassword: _masterPassword,
        );

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
      },
    );

    test(
      'contraseña incorrecta: no escribe nada localmente, el error queda '
      'en vaultAuthAttemptProvider y la sesión sigue sin bóveda',
      () async {
        final built = _buildContainerWithSync();
        final container = built.container;
        final notifier = container.read(
          vaultSessionControllerProvider.notifier,
        );
        await container.read(vaultSessionControllerProvider.future);

        final remoteStorage = FakeVaultStoragePort();
        await CreateVaultUseCase(
          storage: remoteStorage,
          crypto: built.fakes.crypto,
        )(masterPassword: _masterPassword);
        final downloadedFile = remoteStorage.stored!;

        await notifier.restoreFromDownloadedFile(
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
      },
    );
  });
}
