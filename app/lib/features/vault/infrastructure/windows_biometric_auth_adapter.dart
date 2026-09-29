// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Gabriel Ángel Montoya Rico

import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';

import '../domain/ports/biometric_auth_port.dart';

const _keyBiometricKey = 'biometric.vault_key';
const _keyOnboardingDismissed = 'biometric.onboarding_dismissed';
const _promptReason = 'Verificate para desbloquear Lockspire';

/// Implementa [BiometricAuthPort] en Windows con `local_auth`
/// (`local_auth_windows`, del propio equipo de Flutter) para disparar el
/// prompt real de Windows Hello (`IUserConsentVerifierInterop.
/// RequestVerificationForWindowAsync` por debajo — confirmado leyendo el
/// código fuente del paquete, no la documentación) antes de leer la
/// clave de un `FlutterSecureStorage` plano.
///
/// **Limitación documentada a propósito, no un descuido** (ver
/// docs/adr/0010-desbloqueo-biometrico.md): a diferencia de Android
/// (Keystore hardware-backed, ver `android_biometric_auth_adapter.dart`),
/// acá el gating es **a nivel de app** — el secreto en sí queda en
/// Credential Manager/DPAPI atado a la sesión de Windows, sin ningún
/// desafío biométrico propio de por medio; es este adaptador el que
/// exige pasar Windows Hello *antes* de leer, no el sistema operativo
/// el que lo exige al liberar el secreto. Windows no expone (por ahora)
/// un primitivo equivalente al Keystore de Android para Flutter.
class WindowsBiometricAuthAdapter implements BiometricAuthPort {
  final FlutterSecureStorage _storage;
  final LocalAuthentication _localAuth;

  WindowsBiometricAuthAdapter({
    required this._storage,
    LocalAuthentication? localAuth,
  }) : _localAuth = localAuth ?? LocalAuthentication();

  @override
  Future<BiometricAvailability> checkAvailability() async {
    final supported = await _localAuth.isDeviceSupported();
    if (!supported) return BiometricAvailability.unavailable;
    return BiometricAvailability.available;
  }

  @override
  Future<bool> hasStoredKey() async =>
      (await _storage.read(key: _keyBiometricKey)) != null;

  @override
  Future<void> storeKey({required Uint8List key}) =>
      _storage.write(key: _keyBiometricKey, value: base64Encode(key));

  @override
  Future<Uint8List?> readKey() async {
    try {
      final verified = await _localAuth.authenticate(
        localizedReason: _promptReason,
      );
      if (!verified) return null;
      final encoded = await _storage.read(key: _keyBiometricKey);
      if (encoded == null) return null;
      return base64Decode(encoded);
    } catch (_) {
      // LocalAuthException (cancelado, timeout, etc.) — nunca se deja
      // escapar, ver el contrato de [BiometricAuthPort.readKey].
      return null;
    }
  }

  @override
  Future<void> deleteKey() => _storage.delete(key: _keyBiometricKey);

  @override
  Future<bool> wasOnboardingDismissed() async =>
      (await _storage.read(key: _keyOnboardingDismissed)) == 'true';

  @override
  Future<void> markOnboardingDismissed() =>
      _storage.write(key: _keyOnboardingDismissed, value: 'true');
}
