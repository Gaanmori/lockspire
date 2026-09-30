// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Gabriel Ángel Montoya Rico

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lockspire/features/vault/presentation/providers/vault_auth_attempt_provider.dart';
import 'package:lockspire/features/vault/presentation/biometric_unlock_controller.dart';
import 'package:lockspire/features/vault/presentation/vault_session_controller.dart';
import 'package:lockspire/features/vault/presentation/vault_session_state.dart';

import 'vault_session_harness.dart';

void main() {
  group('VaultSessionController — desbloqueo biométrico (ADR 0010)', () {
    test('enable() no hace nada si la bóveda no está desbloqueada', () async {
      final built = buildSessionContainer(timeout: const Duration(minutes: 5));
      final container = built.container;
      await container.read(vaultSessionControllerProvider.future);

      await container.read(biometricUnlockControllerProvider).enable();

      expect(await built.fakes.biometric.hasStoredKey(), isFalse);
    });

    test('enable() guarda la clave de la sesión actual', () async {
      final built = buildSessionContainer(timeout: const Duration(minutes: 5));
      final container = built.container;
      final notifier = container.read(vaultSessionControllerProvider.notifier);
      await container.read(vaultSessionControllerProvider.future);
      await notifier.createVault(masterPassword);

      await container.read(biometricUnlockControllerProvider).enable();

      expect(await built.fakes.biometric.hasStoredKey(), isTrue);
    });

    test('disable() borra la clave guardada', () async {
      final built = buildSessionContainer(timeout: const Duration(minutes: 5));
      final container = built.container;
      final notifier = container.read(vaultSessionControllerProvider.notifier);
      await container.read(vaultSessionControllerProvider.future);
      await notifier.createVault(masterPassword);
      await container.read(biometricUnlockControllerProvider).enable();

      await container.read(biometricUnlockControllerProvider).disable();

      expect(await built.fakes.biometric.hasStoredKey(), isFalse);
    });

    test('unlockWithBiometrics() con el prompt cancelado (readKey -> null) no '
        'cambia el estado de sesión — sigue Locked, sin error', () async {
      final built = buildSessionContainer(timeout: const Duration(minutes: 5));
      final container = built.container;
      final notifier = container.read(vaultSessionControllerProvider.notifier);
      await container.read(vaultSessionControllerProvider.future);
      await notifier.createVault(masterPassword);
      notifier.lock();
      built.fakes.biometric.nextReadKeyResult = null;

      await notifier.unlockWithBiometrics();

      expect(
        container.read(vaultSessionControllerProvider).value,
        isA<VaultSessionLocked>(),
      );
      expect(container.read(vaultAuthAttemptProvider).hasError, isFalse);
    });

    test('unlockWithBiometrics() con una clave válida desbloquea sin volver a '
        'derivar (no pide la contraseña maestra de nuevo)', () async {
      final built = buildSessionContainer(timeout: const Duration(minutes: 5));
      final container = built.container;
      final notifier = container.read(vaultSessionControllerProvider.notifier);
      await container.read(vaultSessionControllerProvider.future);
      await notifier.createVault(masterPassword);
      final key =
          (container.read(vaultSessionControllerProvider).value
                  as VaultSessionUnlocked)
              .key;
      notifier.lock();
      final callsAfterCreate = built.fakes.crypto.deriveKeyCalls;

      built.fakes.biometric.nextReadKeyResult = key;
      await notifier.unlockWithBiometrics();

      expect(
        container.read(vaultSessionControllerProvider).value,
        isA<VaultSessionUnlocked>(),
      );
      expect(built.fakes.crypto.deriveKeyCalls, callsAfterCreate);
    });
  });
}
