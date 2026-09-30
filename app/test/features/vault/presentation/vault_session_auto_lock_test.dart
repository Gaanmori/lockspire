// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Gabriel Ángel Montoya Rico

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lockspire/features/clipboard/presentation/providers/clipboard_guard_provider.dart';
import 'package:lockspire/features/vault/presentation/providers/auto_lock_timeout_provider.dart';
import 'package:lockspire/features/vault/presentation/providers/biometric_auth_port_provider.dart';
import 'package:lockspire/features/vault/presentation/providers/crypto_port_provider.dart';
import 'package:lockspire/features/vault/presentation/providers/lock_on_background_provider.dart';
import 'package:lockspire/features/vault/presentation/providers/vault_auth_attempt_provider.dart';
import 'package:lockspire/features/vault/presentation/providers/vault_storage_port_provider.dart';
import 'package:lockspire/features/vault/presentation/auto_lock_controller.dart';
import 'package:lockspire/features/vault/presentation/vault_session_controller.dart';
import 'package:lockspire/features/vault/presentation/vault_session_state.dart';
import '../../../support/fakes/vault_fakes.dart';
import '../../../support/fakes/fake_secure_clipboard.dart';

import 'vault_session_harness.dart';

void main() {
  group(
    'VaultSessionController — tiempo de bloqueo configurable (ADR 0016)',
    () {
      test(
        'al cambiar el tiempo, reprograma el temporizador en curso sin '
        'esperar a la próxima interacción',
        () => withFakeClock((clock, settle) {
          // Fuente mutable del tiempo: se cambia la variable e invalida el
          // provider, igual que cuando el usuario elige otro valor.
          var timeout = const Duration(minutes: 5);
          final timeoutSource = Provider<Duration>((ref) => timeout);
          final container = ProviderContainer(
            overrides: [
              cryptoPortProvider.overrideWith((ref) async => FakeCryptoPort()),
              vaultStoragePortProvider.overrideWith(
                (ref) async => FakeVaultStoragePort(),
              ),
              autoLockTimeoutProvider.overrideWith(
                (ref) => ref.watch(timeoutSource),
              ),
              lockOnBackgroundProvider.overrideWith((ref) => true),
              biometricAuthPortProvider.overrideWith(
                (ref) => FakeBiometricAuthPort(),
              ),
              ...reminderOverrides(FakePasswordUnlockHistoryPort()),
            ],
          );
          addTearDown(container.dispose);
          container.read(autoLockControllerProvider);
          final notifier = container.read(
            vaultSessionControllerProvider.notifier,
          );
          settle(container.read(vaultSessionControllerProvider.future));
          settle(notifier.createVault(masterPassword));

          // Con 5 minutos no se bloquearía en el tiempo del test...
          timeout = shortTimeout;
          container.invalidate(timeoutSource);
          container.read(autoLockTimeoutProvider);
          clock.elapse(shortTimeout * 3);

          // ...pero el controller reprogramó con el valor nuevo.
          expect(
            container.read(vaultSessionControllerProvider).value,
            isA<VaultSessionLocked>(),
          );
        }),
      );
    },
  );

  group('VaultSessionController — auto-lock (ADR 0008)', () {
    test(
      'bloquea automáticamente al superar el timeout de inactividad',
      () => withFakeClock((clock, settle) {
        final built = buildSessionContainer();
        final container = built.container;
        final notifier = container.read(
          vaultSessionControllerProvider.notifier,
        );
        settle(container.read(vaultSessionControllerProvider.future));
        settle(notifier.createVault(masterPassword));

        expect(
          container.read(vaultSessionControllerProvider).value,
          isA<VaultSessionUnlocked>(),
        );

        clock.elapse(shortTimeout * 3);

        expect(
          container.read(vaultSessionControllerProvider).value,
          isA<VaultSessionLocked>(),
        );
      }),
    );

    test(
      'registerActivity() reinicia el timer y evita el bloqueo',
      () => withFakeClock((clock, settle) {
        final built = buildSessionContainer();
        final container = built.container;
        final notifier = container.read(
          vaultSessionControllerProvider.notifier,
        );
        settle(container.read(vaultSessionControllerProvider.future));
        settle(notifier.createVault(masterPassword));

        // A mitad del timeout original se registra actividad -> se reinicia.
        clock.elapse(shortTimeout ~/ 2);
        container.read(autoLockControllerProvider).registerActivity();
        clock.elapse(shortTimeout ~/ 2 + const Duration(milliseconds: 15));

        // Ya pasó el timeout ORIGINAL, pero como se reinició, sigue desbloqueada.
        expect(
          container.read(vaultSessionControllerProvider).value,
          isA<VaultSessionUnlocked>(),
        );

        // Tras el nuevo timeout completo (desde el reinicio), sí se bloquea.
        clock.elapse(shortTimeout);
        expect(
          container.read(vaultSessionControllerProvider).value,
          isA<VaultSessionLocked>(),
        );
      }),
    );

    test(
      'onAppLifecycleChanged(paused) bloquea inmediatamente, sin esperar el timer',
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

        container
            .read(autoLockControllerProvider)
            .onAppLifecycleChanged(AppLifecycleState.paused);

        expect(
          container.read(vaultSessionControllerProvider).value,
          isA<VaultSessionLocked>(),
        );
      },
    );

    // Regresión: en Android el usuario sale de Lockspire para pegar en otra
    // app. Si el bloqueo por segundo plano borraba el portapapeles, pegar
    // era imposible. Lo borra el plazo de ClipboardGuard.
    test('pasar a segundo plano bloquea pero NO borra el portapapeles; '
        'bloquear a mano sí (S4)', () async {
      final clipboard = FakeSecureClipboard();
      final built = buildSessionContainer(
        timeout: const Duration(minutes: 5),
        clipboard: clipboard,
      );
      final container = built.container;
      final notifier = built.container.read(
        vaultSessionControllerProvider.notifier,
      );
      await built.container.read(vaultSessionControllerProvider.future);
      await notifier.createVault(masterPassword);
      await container.read(clipboardGuardProvider).copy('secreto');

      container
          .read(autoLockControllerProvider)
          .onAppLifecycleChanged(AppLifecycleState.paused);
      await Future<void>.delayed(Duration.zero);
      expect(
        built.container.read(vaultSessionControllerProvider).value,
        isA<VaultSessionLocked>(),
      );
      expect(clipboard.clears, 0);

      notifier.lock();
      await Future<void>.delayed(Duration.zero);
      expect(clipboard.clears, 1);
    });

    test(
      'onAppLifecycleChanged(inactive) NO bloquea (se ignora a propósito)',
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

        container
            .read(autoLockControllerProvider)
            .onAppLifecycleChanged(AppLifecycleState.inactive);

        expect(
          container.read(vaultSessionControllerProvider).value,
          isA<VaultSessionUnlocked>(),
        );
      },
    );

    test(
      'escritorio (ADR 0012): paused/hidden NO bloquean — la app vive en '
      'la bandeja; el timer de inactividad sigue corriendo',
      () => withFakeClock((clock, settle) {
        final built = buildSessionContainer(lockOnBackground: false);
        final container = built.container;
        final notifier = container.read(
          vaultSessionControllerProvider.notifier,
        );
        settle(container.read(vaultSessionControllerProvider.future));
        settle(notifier.createVault(masterPassword));

        container
            .read(autoLockControllerProvider)
            .onAppLifecycleChanged(AppLifecycleState.hidden);
        container
            .read(autoLockControllerProvider)
            .onAppLifecycleChanged(AppLifecycleState.paused);
        expect(
          container.read(vaultSessionControllerProvider).value,
          isA<VaultSessionUnlocked>(),
        );

        clock.elapse(shortTimeout * 3);
        expect(
          container.read(vaultSessionControllerProvider).value,
          isA<VaultSessionLocked>(),
        );
      }),
    );

    test('registerActivity() y onAppLifecycleChanged() durante el await de '
        'createVault()/unlock() no lanzan excepción — y el estado de sesión '
        '(a diferencia de vaultAuthAttemptProvider) ni se entera de que hay '
        'un intento en curso, ver vault_auth_attempt_provider.dart', () async {
      final built = buildSessionContainer(timeout: const Duration(minutes: 5));
      final container = built.container;
      final notifier = container.read(vaultSessionControllerProvider.notifier);
      await container.read(vaultSessionControllerProvider.future);

      // No se espera el Future — se dispara actividad/lifecycle mientras
      // sigue pendiente, exactamente la ventana de los ~3.5s de Argon2id.
      final createFuture = notifier.createVault(masterPassword);

      // El estado de sesión sigue siendo el de antes de empezar — no pasa
      // por AsyncLoading, así que .value nunca es null durante este
      // intento (el progreso vive aparte, en vaultAuthAttemptProvider).
      expect(
        container.read(vaultSessionControllerProvider).value,
        isA<VaultSessionNoVault>(),
      );
      expect(container.read(vaultAuthAttemptProvider).isLoading, isTrue);

      expect(
        () => container.read(autoLockControllerProvider).registerActivity(),
        returnsNormally,
      );
      expect(
        () => container
            .read(autoLockControllerProvider)
            .onAppLifecycleChanged(AppLifecycleState.paused),
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
      final built = buildSessionContainer(timeout: const Duration(minutes: 5));
      final container = built.container;
      final notifier = container.read(vaultSessionControllerProvider.notifier);
      await container.read(vaultSessionControllerProvider.future);
      await notifier.createVault(masterPassword);
      notifier.lock();

      await notifier.unlock('contraseña-incorrecta');

      expect(
        container.read(vaultSessionControllerProvider).value,
        isA<VaultSessionLocked>(),
      );
      expect(container.read(vaultAuthAttemptProvider).hasError, isTrue);
    });
  });
}
