// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Lockspire

import 'dart:typed_data';

import '../domain/ports/biometric_auth_port.dart';

/// Implementación no-op de [BiometricAuthPort] para cualquier plataforma
/// que no sea Android o Windows (ver docs/adr/0010-desbloqueo-biometrico.md
/// — alcance explícitamente limitado a esas dos). Siempre reporta
/// [BiometricAvailability.unavailable] y nunca guarda nada — evita que
/// la app crashee si algún día corre en iOS/macOS/Linux/web en vez de
/// tener que ramificar por plataforma en cada lugar que use el puerto.
class UnavailableBiometricAuthAdapter implements BiometricAuthPort {
  const UnavailableBiometricAuthAdapter();

  @override
  Future<BiometricAvailability> checkAvailability() async =>
      BiometricAvailability.unavailable;

  @override
  Future<bool> hasStoredKey() async => false;

  @override
  Future<void> storeKey({required Uint8List key}) async {}

  @override
  Future<Uint8List?> readKey() async => null;

  @override
  Future<void> deleteKey() async {}

  @override
  Future<bool> wasOnboardingDismissed() async => true;

  @override
  Future<void> markOnboardingDismissed() async {}
}
