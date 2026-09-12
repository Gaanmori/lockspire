// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Lockspire

import 'package:local_auth/local_auth.dart';
import 'package:local_auth_platform_interface/local_auth_platform_interface.dart'
    show AuthMessages;

/// `LocalAuthentication` falso para tests — `LocalAuthentication` es una
/// clase concreta normal (no `final`/`sealed`), así que se puede
/// subclasificar directo, sin necesitar un framework de mocks. Permite
/// probar la lógica propia de `AndroidBiometricAuthAdapter`/
/// `WindowsBiometricAuthAdapter` (manejo de cancelación/fallo,
/// [BiometricAuthPort.checkAvailability] sin disparar el prompt real)
/// sin tocar ningún platform channel real.
class FakeLocalAuthentication extends LocalAuthentication {
  bool authenticateCalled = false;
  bool authenticateResult = true;

  /// Si no es `null`, `authenticate()` lo lanza en vez de devolver
  /// [authenticateResult] — simula un `LocalAuthException` real
  /// (cancelado, timeout, etc.).
  Object? authenticateError;

  bool deviceSupported = true;
  bool canCheck = true;
  List<BiometricType> enrolled = const [BiometricType.fingerprint];

  @override
  Future<bool> authenticate({
    required String localizedReason,
    // El valor por defecto real (con IOSAuthMessages/AndroidAuthMessages/
    // WindowsAuthMessages) vive en local_auth_android/darwin/windows, no
    // en local_auth_platform_interface — y de todos modos nunca se usa
    // acá: en Dart, el default de un parámetro opcional se resuelve según
    // el tipo estático del sitio de la llamada (LocalAuthentication en
    // los adaptadores reales), no según esta subclase. Una lista vacía
    // alcanza para que el override compile.
    Iterable<AuthMessages> authMessages = const <AuthMessages>[],
    bool biometricOnly = false,
    bool sensitiveTransaction = true,
    bool persistAcrossBackgrounding = false,
  }) async {
    authenticateCalled = true;
    final error = authenticateError;
    if (error != null) throw error;
    return authenticateResult;
  }

  @override
  Future<bool> isDeviceSupported() async => deviceSupported;

  @override
  Future<bool> get canCheckBiometrics async => canCheck;

  @override
  Future<List<BiometricType>> getAvailableBiometrics() async => enrolled;
}
