// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Gabriel Ángel Montoya Rico

import 'dart:typed_data';

/// Disponibilidad de desbloqueo biométrico en este dispositivo — ver
/// docs/adr/0010-desbloqueo-biometrico.md.
enum BiometricAvailability { available, noHardware, notEnrolled, unavailable }

/// Puerto para cachear la clave ya derivada (Argon2id) detrás de la
/// biometría/PIN del sistema operativo (huella en Android, Windows Hello
/// en escritorio), para no tener que re-derivar ni volver a pedir la
/// contraseña maestra en cada desbloqueo — ver
/// docs/adr/0010-desbloqueo-biometrico.md.
///
/// **Nunca deriva ni reemplaza Argon2id** — solo guarda/recupera una
/// clave que ya fue derivada por un desbloqueo real con contraseña
/// (docs/adr/0002-motor-criptografico.md ya anticipaba esto como
/// mitigación de UX, no como atajo criptográfico).
///
/// Los adaptadores (infrastructure/) son específicos por plataforma —
/// el gating real difiere: en Android es a nivel de Android Keystore
/// (hardware/TEE-backed), en Windows es un chequeo a nivel de app antes
/// de leer un secreto plano (limitación documentada en el ADR). El
/// dominio/aplicación nunca necesita saber cuál de los dos hay debajo.
abstract class BiometricAuthPort {
  /// Si este dispositivo puede ofrecer desbloqueo biométrico ahora mismo
  /// — sin disparar ningún prompt del sistema operativo.
  Future<BiometricAvailability> checkAvailability();

  /// Si ya hay una clave guardada (el usuario activó esta feature antes).
  Future<bool> hasStoredKey();

  /// Guarda [key] detrás de la biometría/PIN del sistema — llamar solo
  /// justo después de un desbloqueo real con contraseña maestra.
  Future<void> storeKey({required Uint8List key});

  /// Dispara el prompt del sistema operativo (huella/Windows Hello) y,
  /// si el usuario lo pasa, devuelve la clave guardada. Devuelve `null`
  /// si el usuario cancela o falla la verificación — **nunca lanza**
  /// para ese caso, solo ante un error real de la plataforma.
  Future<Uint8List?> readKey();

  /// Borra la clave guardada — desactiva el desbloqueo biométrico.
  Future<void> deleteKey();

  /// Para el aviso único de opt-in tras el primer desbloqueo con
  /// contraseña (ver docs/STATE.md) — si ya se le preguntó al usuario
  /// una vez y no quiso activarlo, no se le vuelve a preguntar.
  Future<bool> wasOnboardingDismissed();

  /// Marca el aviso de opt-in como ya mostrado — ver [wasOnboardingDismissed].
  Future<void> markOnboardingDismissed();
}
