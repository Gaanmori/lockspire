// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Lockspire

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lockspire/features/vault/presentation/providers/auto_lock_timeout_provider.dart';
import 'package:lockspire/features/vault/presentation/providers/crypto_port_provider.dart';
import 'package:lockspire/features/vault/presentation/providers/vault_storage_port_provider.dart';
import 'package:lockspire/features/vault/presentation/vault_session_controller.dart';
import 'package:lockspire/features/vault/presentation/vault_session_state.dart';

import '../application/fakes.dart';

// Duración corta para no esperar minutos reales en los tests — usa Timer
// real, así que hay margen inherente de timing (ver docs/STATE.md, nota
// de la Fase 3: si aparece flakiness intermitente, migrar a fake_async).
const _shortTimeout = Duration(milliseconds: 60);
const _masterPassword = 'correcto-caballo-batería-grapa';

ProviderContainer _buildContainer({Duration timeout = _shortTimeout}) {
  final container = ProviderContainer(
    overrides: [
      cryptoPortProvider.overrideWith((ref) async => FakeCryptoPort()),
      vaultStoragePortProvider.overrideWith(
        (ref) async => FakeVaultStoragePort(),
      ),
      autoLockTimeoutProvider.overrideWith((ref) => timeout),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  group('VaultSessionController — auto-lock (ADR 0008)', () {
    test(
      'bloquea automáticamente al superar el timeout de inactividad',
      () async {
        final container = _buildContainer();
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
      final container = _buildContainer();
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
        final container = _buildContainer(timeout: const Duration(minutes: 5));
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
        final container = _buildContainer(timeout: const Duration(minutes: 5));
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
        'createVault()/unlock() (state == AsyncLoading, sin valor previo) '
        'no lanzan excepción', () async {
      final container = _buildContainer(timeout: const Duration(minutes: 5));
      final notifier = container.read(vaultSessionControllerProvider.notifier);
      await container.read(vaultSessionControllerProvider.future);

      // No se espera el Future — se dispara actividad/lifecycle mientras
      // sigue pendiente, exactamente la ventana de los ~3.5s de Argon2id.
      final createFuture = notifier.createVault(_masterPassword);
      expect(
        container.read(vaultSessionControllerProvider),
        isA<AsyncLoading<VaultSessionState>>(),
      );

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
    });
  });
}
