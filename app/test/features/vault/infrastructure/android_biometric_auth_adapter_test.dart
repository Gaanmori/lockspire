// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Gabriel Ángel Montoya Rico

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:local_auth_platform_interface/local_auth_platform_interface.dart';
import 'package:lockspire/features/vault/domain/ports/biometric_auth_port.dart';
import 'package:lockspire/features/vault/infrastructure/android_biometric_auth_adapter.dart';

import '../../../support/fakes/fake_local_authentication.dart';

void main() {
  // Acá solo la disponibilidad y los fallos del diálogo del sistema: la
  // clave guardada se prueba en `biometric_key_storage_test.dart`.
  const storage = FlutterSecureStorage();

  group('AndroidBiometricAuthAdapter', () {
    test(
      'readKey() ante cancelación (LocalAuthException) devuelve null sin lanzar',
      () async {
        final localAuth = FakeLocalAuthentication()
          ..authenticateError = const LocalAuthException(
            code: LocalAuthExceptionCode.userCanceled,
          );
        final adapter = AndroidBiometricAuthAdapter(
          promptReason: 'Verifíquese para desbloquear Lockspire',
          storage: storage,
          localAuth: localAuth,
        );

        final result = await adapter.readKey();

        expect(result, isNull);
      },
    );

    test(
      'readKey() ante rechazo sin error (authenticate() devuelve false) devuelve null',
      () async {
        final localAuth = FakeLocalAuthentication()..authenticateResult = false;
        final adapter = AndroidBiometricAuthAdapter(
          promptReason: 'Verifíquese para desbloquear Lockspire',
          storage: storage,
          localAuth: localAuth,
        );

        final result = await adapter.readKey();

        expect(result, isNull);
      },
    );

    test(
      'checkAvailability() con todo disponible devuelve available y nunca dispara el prompt',
      () async {
        final localAuth = FakeLocalAuthentication();
        final adapter = AndroidBiometricAuthAdapter(
          promptReason: 'Verifíquese para desbloquear Lockspire',
          storage: storage,
          localAuth: localAuth,
        );

        final availability = await adapter.checkAvailability();

        expect(availability, BiometricAvailability.available);
        expect(localAuth.authenticateCalled, isFalse);
      },
    );

    test(
      'checkAvailability() sin soporte de dispositivo devuelve unavailable',
      () async {
        final localAuth = FakeLocalAuthentication()..deviceSupported = false;
        final adapter = AndroidBiometricAuthAdapter(
          promptReason: 'Verifíquese para desbloquear Lockspire',
          storage: storage,
          localAuth: localAuth,
        );

        final availability = await adapter.checkAvailability();

        expect(availability, BiometricAvailability.unavailable);
      },
    );

    test(
      'checkAvailability() sin poder chequear biometría devuelve noHardware',
      () async {
        final localAuth = FakeLocalAuthentication()..canCheck = false;
        final adapter = AndroidBiometricAuthAdapter(
          promptReason: 'Verifíquese para desbloquear Lockspire',
          storage: storage,
          localAuth: localAuth,
        );

        final availability = await adapter.checkAvailability();

        expect(availability, BiometricAvailability.noHardware);
      },
    );

    test(
      'checkAvailability() sin biometría enrolada devuelve notEnrolled',
      () async {
        final localAuth = FakeLocalAuthentication()..enrolled = const [];
        final adapter = AndroidBiometricAuthAdapter(
          promptReason: 'Verifíquese para desbloquear Lockspire',
          storage: storage,
          localAuth: localAuth,
        );

        final availability = await adapter.checkAvailability();

        expect(availability, BiometricAvailability.notEnrolled);
      },
    );
  });
}
