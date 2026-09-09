// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Lockspire

import 'dart:typed_data';

/// Resultado de una operación de cifrado autenticado (AEAD).
///
/// [ciphertext] incluye el tag de autenticación de Poly1305 al final,
/// coherente con la salida estándar de XChaCha20-Poly1305.
class EncryptedPayload {
  final Uint8List nonce;
  final Uint8List ciphertext;

  const EncryptedPayload({required this.nonce, required this.ciphertext});
}

/// Puerto del motor criptográfico. La firma refleja las decisiones ya
/// tomadas en docs/adr/0002-motor-criptografico.md: Argon2id como KDF y
/// XChaCha20-Poly1305 como AEAD, con soporte de datos autenticados
/// adicionales (AAD) para el header del archivo de bóveda.
///
/// Los adaptadores que implementen este puerto (infrastructure/) deben usar
/// bindings nativos de libsodium — nunca una reimplementación pura en Dart.
abstract class CryptoPort {
  /// Deriva la clave simétrica de [masterPassword] vía Argon2id usando [salt].
  Future<Uint8List> deriveKey({
    required String masterPassword,
    required Uint8List salt,
  });

  /// Cifra [plaintext] con XChaCha20-Poly1305, autenticando (sin cifrar) [aad].
  Future<EncryptedPayload> encrypt({
    required Uint8List key,
    required Uint8List plaintext,
    required Uint8List aad,
  });

  /// Desencripta [payload], verificando que [aad] no fue manipulado.
  ///
  /// Debe lanzar si la autenticación falla — nunca degradar en silencio.
  Future<Uint8List> decrypt({
    required Uint8List key,
    required EncryptedPayload payload,
    required Uint8List aad,
  });

  /// Genera un salt aleatorio criptográficamente seguro para Argon2id.
  Uint8List generateSalt();
}
