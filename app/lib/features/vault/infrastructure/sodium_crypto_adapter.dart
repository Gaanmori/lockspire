// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Lockspire

import 'dart:typed_data';

import 'package:sodium/sodium_sumo.dart';

import '../domain/ports/argon2_params.dart';
import '../domain/ports/crypto_port.dart';

/// Implementación de [CryptoPort] con bindings nativos de libsodium (ver
/// docs/adr/0002-motor-criptografico.md).
///
/// Requiere la variante "sumo" de libsodium ([SodiumSumo]) porque la API de
/// Argon2id (`crypto_pwhash`) solo está expuesta ahí en el paquete `sodium`.
class SodiumCryptoAdapter implements CryptoPort {
  final SodiumSumo sodium;

  const SodiumCryptoAdapter(this.sodium);

  @override
  Uint8List generateSalt() =>
      sodium.randombytes.buf(sodium.crypto.pwhash.saltBytes);

  @override
  Future<Uint8List> deriveKey({
    required String masterPassword,
    required Uint8List salt,
    required Argon2Params params,
  }) async {
    // Ver docs/adr/0007-paralelismo-argon2id-libsodium.md: crypto_pwhash
    // (la única API de Argon2id que expone el paquete) siempre usa
    // paralelismo=1. Si params.parallelism fuera distinto, derivar de
    // todas formas produciría una clave distinta a la que el header dice
    // haber usado — un bug de pérdida de datos, no solo de seguridad. Se
    // rechaza explícitamente en vez de ignorar el valor en silencio.
    if (params.parallelism != 1) {
      throw ArgumentError.value(
        params.parallelism,
        'params.parallelism',
        'crypto_pwhash de libsodium solo soporta paralelismo=1 '
            '(ver docs/adr/0007-paralelismo-argon2id-libsodium.md)',
      );
    }

    // sodium.crypto.pwhash.callStr() es una llamada FFI síncrona — pese a
    // que este método es `async`, sin un `await` real de por medio esos
    // ~3.5s de Argon2id bloquean el isolate completo (no solo la UI: toda
    // animación/gesto se congela), no solo el widget del spinner. La propia
    // documentación del paquete `sodium` marca correr esto en un isolate
    // aparte como obligatorio ("running the computation on a separate
    // isolate is mandatory to not block the UI") y provee `runIsolated()`
    // para esto — `compute()`/`Isolate.run()` normales no sirven porque no
    // se puede pasar una instancia de `Sodium`/`SodiumSumo` entre isolates.
    final opsLimit = params.iterations;
    final memLimit = params.memoryKib * 1024;
    return sodium.runIsolated((secureKeys, keyPairs) {
      final key = sodium.crypto.pwhash.callStr(
        outLen: sodium.crypto.aeadXChaCha20Poly1305IETF.keyBytes,
        password: masterPassword,
        salt: salt,
        opsLimit: opsLimit,
        memLimit: memLimit,
        alg: CryptoPwhashAlgorithm.argon2id13,
      );
      try {
        return key.extractBytes();
      } finally {
        key.dispose();
      }
    });
  }

  @override
  Future<EncryptedPayload> encrypt({
    required Uint8List key,
    required Uint8List plaintext,
    required Uint8List aad,
  }) async {
    final aead = sodium.crypto.aeadXChaCha20Poly1305IETF;
    final nonce = sodium.randombytes.buf(aead.nonceBytes);
    final secureKey = SecureKey.fromList(sodium, key);
    try {
      final ciphertext = aead.encrypt(
        message: plaintext,
        nonce: nonce,
        key: secureKey,
        additionalData: aad,
      );
      return EncryptedPayload(nonce: nonce, ciphertext: ciphertext);
    } finally {
      secureKey.dispose();
    }
  }

  @override
  Future<Uint8List> decrypt({
    required Uint8List key,
    required EncryptedPayload payload,
    required Uint8List aad,
  }) async {
    final aead = sodium.crypto.aeadXChaCha20Poly1305IETF;
    final secureKey = SecureKey.fromList(sodium, key);
    try {
      // aead.decrypt lanza SodiumException si la autenticación falla
      // (AAD, nonce, clave o ciphertext no coinciden) — nunca degrada en
      // silencio, coherente con ADR 0002/0004.
      return aead.decrypt(
        cipherText: payload.ciphertext,
        nonce: payload.nonce,
        key: secureKey,
        additionalData: aad,
      );
    } finally {
      secureKey.dispose();
    }
  }
}
