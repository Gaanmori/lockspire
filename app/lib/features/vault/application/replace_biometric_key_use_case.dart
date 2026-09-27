// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Lockspire

import 'dart:typed_data';

import '../domain/ports/biometric_auth_port.dart';

/// Tras cambiar la clave de la bóveda (ADR 0018), la cacheada para
/// biometría (ADR 0010) ya no la abre. Si había una, se borra siempre y se
/// intenta guardar la nueva. Guardar puede pedir la biometría o fallar; en
/// ese caso queda desactivada y el usuario la reactiva en Seguridad: nunca
/// queda cacheada una clave que no abre.
class ReplaceBiometricKeyUseCase {
  final BiometricAuthPort port;

  const ReplaceBiometricKeyUseCase(this.port);

  Future<void> call(Uint8List newKey) async {
    try {
      if (!await port.hasStoredKey()) return;
      await port.deleteKey();
      await port.storeKey(key: newKey);
    } catch (_) {}
  }
}
