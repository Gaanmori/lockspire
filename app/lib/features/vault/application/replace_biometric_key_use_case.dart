// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Lockspire

import 'dart:typed_data';

import '../domain/ports/biometric_auth_port.dart';

/// Tras cambiar la clave de la bóveda (ADR 0018), la cacheada para
/// biometría (ADR 0010) ya no la abre. Si había una, se **sobrescribe** con
/// la nueva, sin borrarla antes: si en medio alguien pregunta si hay
/// biometría configurada (el aviso para activarla), la respuesta sigue
/// siendo sí. Si guardar falla, se borra: queda desactivada y el usuario
/// la reactiva en Seguridad, pero nunca queda cacheada una clave que no
/// abre.
class ReplaceBiometricKeyUseCase {
  final BiometricAuthPort port;

  const ReplaceBiometricKeyUseCase(this.port);

  Future<void> call(Uint8List newKey) async {
    try {
      if (!await port.hasStoredKey()) return;
    } catch (_) {
      return;
    }
    try {
      await port.storeKey(key: newKey);
    } catch (_) {
      try {
        await port.deleteKey();
      } catch (_) {}
    }
  }
}
