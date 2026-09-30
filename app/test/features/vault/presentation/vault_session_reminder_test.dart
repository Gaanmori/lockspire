// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Gabriel Ángel Montoya Rico

import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lockspire/features/vault/presentation/biometric_unlock_controller.dart';
import 'package:lockspire/features/vault/presentation/vault_session_controller.dart';
import 'package:lockspire/features/vault/presentation/vault_session_state.dart';

import 'vault_session_harness.dart';

void main() {
  group('VaultSessionController — pedir la contraseña maestra cada N días '
      '(ADR 0017)', () {
    Future<Uint8List> enableBiometrics(
      ProviderContainer container,
      SessionTestFakes fakes,
    ) async {
      final notifier = container.read(vaultSessionControllerProvider.notifier);
      await container.read(vaultSessionControllerProvider.future);
      await notifier.createVault(masterPassword);
      await container.read(biometricUnlockControllerProvider).enable();
      final key =
          (container.read(vaultSessionControllerProvider).value!
                  as VaultSessionUnlocked)
              .key;
      notifier.lock();
      return key;
    }

    test('crear o desbloquear con contraseña registra la fecha', () async {
      final now = DateTime.utc(2026, 9, 25, 10);
      final built = buildSessionContainer(
        timeout: const Duration(minutes: 5),
        clock: () => now,
      );
      final notifier = built.container.read(
        vaultSessionControllerProvider.notifier,
      );
      await built.container.read(vaultSessionControllerProvider.future);
      await notifier.createVault(masterPassword);
      expect(built.fakes.history.last, now);
    });

    test('dentro del plazo, la biometría desbloquea', () async {
      var now = DateTime.utc(2026, 9, 25);
      final built = buildSessionContainer(
        timeout: const Duration(minutes: 5),
        clock: () => now,
      );
      final key = await enableBiometrics(built.container, built.fakes);

      now = now.add(const Duration(days: 13));
      built.fakes.biometric.nextReadKeyResult = key;
      await built.container
          .read(vaultSessionControllerProvider.notifier)
          .unlockWithBiometrics();

      expect(
        built.container.read(vaultSessionControllerProvider).value,
        isA<VaultSessionUnlocked>(),
      );
    });

    test('vencido el plazo, la biometría no desbloquea aunque la huella sea '
        'correcta; tras usar la contraseña vuelve a funcionar', () async {
      var now = DateTime.utc(2026, 9, 25);
      final built = buildSessionContainer(
        timeout: const Duration(minutes: 5),
        clock: () => now,
      );
      final notifier = built.container.read(
        vaultSessionControllerProvider.notifier,
      );
      final key = await enableBiometrics(built.container, built.fakes);

      now = now.add(const Duration(days: 14));
      built.fakes.biometric.nextReadKeyResult = key;
      await notifier.unlockWithBiometrics();
      expect(
        built.container.read(vaultSessionControllerProvider).value,
        isA<VaultSessionLocked>(),
      );

      await notifier.unlock(masterPassword);
      notifier.lock();
      await notifier.unlockWithBiometrics();
      expect(
        built.container.read(vaultSessionControllerProvider).value,
        isA<VaultSessionUnlocked>(),
      );
    });
  });
}
