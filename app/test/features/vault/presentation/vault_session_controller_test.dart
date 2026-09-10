// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Lockspire

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lockspire/features/vault/application/save_vault_use_case.dart';
import 'package:lockspire/features/vault/domain/entities/vault_entry.dart';
import 'package:lockspire/features/vault/presentation/providers/auto_lock_timeout_provider.dart';
import 'package:lockspire/features/vault/presentation/providers/crypto_port_provider.dart';
import 'package:lockspire/features/vault/presentation/providers/vault_auth_attempt_provider.dart';
import 'package:lockspire/features/vault/presentation/providers/vault_storage_port_provider.dart';
import 'package:lockspire/features/vault/presentation/vault_session_controller.dart';
import 'package:lockspire/features/vault/presentation/vault_session_state.dart';

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
  });
}
