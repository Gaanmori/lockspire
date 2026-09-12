// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Lockspire

import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';

import '../domain/ports/biometric_auth_port.dart';

const _keyBiometricKey = 'biometric.vault_key';
const _keyOnboardingDismissed = 'biometric.onboarding_dismissed';
const _promptReason = 'Verificate para desbloquear Lockspire';

/// Implementa [BiometricAuthPort] en Android con `local_auth`
/// (`BiometricPrompt` real) para disparar el prompt del sistema antes de
/// leer la clave de un `FlutterSecureStorage` plano — mismo patrón que
/// `windows_biometric_auth_adapter.dart`.
///
/// **No usa `AndroidOptions.biometric` de `flutter_secure_storage`** —
/// se intentó primero (gating a nivel de Android Keystore,
/// hardware/TEE-backed, la opción documentada como más fuerte en
/// docs/adr/0010-desbloqueo-biometrico.md) pero se descartó tras
/// verificación manual real: el plugin cachea el cifrado de datos ya
/// desenvuelto a nivel del objeto Java del plugin (`storageCipher`,
/// campo de instancia, ver el código fuente de
/// `FlutterSecureStorage.java`) — una vez pasada la biometría una vez
/// dentro del proceso de la app, **todas las lecturas siguientes la
/// reusan sin volver a pedirla**, sin importar cuántas veces la app
/// llame a `lock()` (eso solo cambia estado de Dart, no toca el caché
/// nativo del plugin). Confirmado con un bug real: tras activar la
/// huella una vez, "Bloquear" + "Usar huella" entraba directo, sin
/// pedir huella de nuevo. `local_auth.authenticate()` no tiene ese
/// problema — cada llamada dispara un `BiometricPrompt` nuevo de
/// verdad, así que el gating pasa a ser explícito acá (mismo trade-off
/// ya aceptado para Windows, ahora también para Android — ver el ADR).
class AndroidBiometricAuthAdapter implements BiometricAuthPort {
  final FlutterSecureStorage _storage;
  final LocalAuthentication _localAuth;

  AndroidBiometricAuthAdapter({
    required this._storage,
    LocalAuthentication? localAuth,
  }) : _localAuth = localAuth ?? LocalAuthentication();

  @override
  Future<BiometricAvailability> checkAvailability() async {
    final supported = await _localAuth.isDeviceSupported();
    if (!supported) return BiometricAvailability.unavailable;
    final canCheck = await _localAuth.canCheckBiometrics;
    if (!canCheck) return BiometricAvailability.noHardware;
    final enrolled = await _localAuth.getAvailableBiometrics();
    if (enrolled.isEmpty) return BiometricAvailability.notEnrolled;
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
