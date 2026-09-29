// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Gabriel Ángel Montoya Rico

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:local_auth_platform_interface/local_auth_platform_interface.dart';
import 'package:lockspire/features/vault/domain/ports/biometric_auth_port.dart';
import 'package:lockspire/features/vault/infrastructure/windows_biometric_auth_adapter.dart';

import 'fake_local_authentication.dart';

void main() {
  // `_storage` nunca se toca en ninguno de los caminos probados acá —
  // ver el comentario del plan aprobado — así que una instancia real
  // alcanza, sin necesitar fakearla.
  const storage = FlutterSecureStorage();

  group('WindowsBiometricAuthAdapter', () {
    test(
      'readKey() ante cancelación (LocalAuthException) devuelve null sin lanzar',
      () async {
        final localAuth = FakeLocalAuthentication()
          ..authenticateError = const LocalAuthException(
            code: LocalAuthExceptionCode.userCanceled,
          );
        final adapter = WindowsBiometricAuthAdapter(
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
        final adapter = WindowsBiometricAuthAdapter(
          promptReason: 'Verifíquese para desbloquear Lockspire',
          storage: storage,
          localAuth: localAuth,
        );

        final result = await adapter.readKey();

        expect(result, isNull);
      },
    );

    test(
      'checkAvailability() con dispositivo soportado devuelve available y nunca dispara el prompt',
      () async {
        final localAuth = FakeLocalAuthentication();
        final adapter = WindowsBiometricAuthAdapter(
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
        // A diferencia de Android, WindowsBiometricAuthAdapter solo
        // consulta isDeviceSupported() — no distingue noHardware/
        // notEnrolled porque su implementación real tampoco lo hace.
        final localAuth = FakeLocalAuthentication()..deviceSupported = false;
        final adapter = WindowsBiometricAuthAdapter(
          promptReason: 'Verifíquese para desbloquear Lockspire',
          storage: storage,
          localAuth: localAuth,
        );

        final availability = await adapter.checkAvailability();

        expect(availability, BiometricAvailability.unavailable);
      },
    );
  });
}
