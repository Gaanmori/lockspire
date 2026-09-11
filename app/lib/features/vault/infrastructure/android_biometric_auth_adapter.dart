// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Lockspire

import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';

import '../domain/ports/biometric_auth_port.dart';

const _keyBiometricKey = 'biometric.vault_key';
const _keyOnboardingDismissed = 'biometric.onboarding_dismissed';

/// Implementa [BiometricAuthPort] en Android usando el gating biométrico
/// real de `flutter_secure_storage` (`AndroidOptions.biometric`, con
/// `enforceBiometrics: true`) — la clave queda envuelta por una clave de
/// Android Keystore con autenticación de usuario requerida
/// (hardware/TEE-backed), no un simple chequeo de UI antes de leer texto
/// plano. El propio `read()`/`write()` de `flutter_secure_storage` ya
/// muestra el prompt del sistema y el Keystore rechaza liberar la clave
/// sin pasarlo — ver docs/adr/0010-desbloqueo-biometrico.md.
///
/// [_localAuth] se usa **solo** para [checkAvailability] (consultar si
/// hay biometría/PIN configurado, sin disparar ningún prompt) — el
/// desafío real ocurre dentro de `flutter_secure_storage`, no acá.
class AndroidBiometricAuthAdapter implements BiometricAuthPort {
  final FlutterSecureStorage _biometricStorage;
  final FlutterSecureStorage plainStorage;
  final LocalAuthentication _localAuth;

  AndroidBiometricAuthAdapter({
    required this.plainStorage,
    LocalAuthentication? localAuth,
  }) : _localAuth = localAuth ?? LocalAuthentication(),
       _biometricStorage = const FlutterSecureStorage(
         aOptions: AndroidOptions.biometric(enforceBiometrics: true),
       );

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
      (await _biometricStorage.read(key: _keyBiometricKey)) != null;

  @override
  Future<void> storeKey({required Uint8List key}) =>
      _biometricStorage.write(key: _keyBiometricKey, value: base64Encode(key));

  @override
  Future<Uint8List?> readKey() async {
    // El prompt del sistema (huella/PIN) lo dispara este mismo read() —
    // si el usuario cancela o falla, flutter_secure_storage lanza; se
    // traduce a `null` acá, nunca se deja escapar la excepción (ver el
    // contrato de [BiometricAuthPort.readKey]).
    try {
      final encoded = await _biometricStorage.read(key: _keyBiometricKey);
      if (encoded == null) return null;
      return base64Decode(encoded);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> deleteKey() => _biometricStorage.delete(key: _keyBiometricKey);

  @override
  Future<bool> wasOnboardingDismissed() async =>
      (await plainStorage.read(key: _keyOnboardingDismissed)) == 'true';

  @override
  Future<void> markOnboardingDismissed() =>
      plainStorage.write(key: _keyOnboardingDismissed, value: 'true');
}
