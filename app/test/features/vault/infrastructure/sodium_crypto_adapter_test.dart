// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Gabriel Ángel Montoya Rico

import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:lockspire/features/vault/domain/ports/argon2_params.dart';
import 'package:lockspire/features/vault/domain/ports/crypto_port.dart';
import 'package:lockspire/features/vault/infrastructure/sodium_crypto_adapter.dart';
import 'package:sodium/sodium_sumo.dart';

void main() {
  late SodiumSumo sodium;
  late SodiumCryptoAdapter adapter;

  // Parámetros mínimos (no los de producción) solo para que los tests de
  // Argon2id corran rápido — la elección de memoria/iteraciones reales para
  // bóvedas de usuarios vive en CreateVaultUseCase.defaultArgon2Params.
  late Argon2Params fastParams;

  setUpAll(() async {
    sodium = await SodiumSumoInit.init();
    adapter = SodiumCryptoAdapter(sodium);
    fastParams = Argon2Params(
      memoryKib: sodium.crypto.pwhash.memLimitInteractive ~/ 1024,
      iterations: sodium.crypto.pwhash.opsLimitInteractive,
      parallelism: 1,
    );
  });

  group('SodiumCryptoAdapter — Argon2id (deriveKey)', () {
    test('es determinista para el mismo salt y contraseña', () async {
      final salt = adapter.generateSalt();

      final key1 = await adapter.deriveKey(
        masterPassword: 'correcto-caballo-batería-grapa',
        salt: salt,
        params: fastParams,
      );
      final key2 = await adapter.deriveKey(
        masterPassword: 'correcto-caballo-batería-grapa',
        salt: salt,
        params: fastParams,
      );

      expect(key1, equals(key2));
    });

    test('produce claves distintas para contraseñas distintas', () async {
      final salt = adapter.generateSalt();

      final key1 = await adapter.deriveKey(
        masterPassword: 'contraseña-uno',
        salt: salt,
        params: fastParams,
      );
      final key2 = await adapter.deriveKey(
        masterPassword: 'contraseña-dos',
        salt: salt,
        params: fastParams,
      );

      expect(key1, isNot(equals(key2)));
    });

    test(
      'rechaza explícitamente parallelism != 1 (ver ADR 0007) — nunca deriva '
      'en silencio con un paralelismo distinto al que crypto_pwhash usa de '
      'verdad',
      () async {
        final salt = adapter.generateSalt();
        final paramsConParalelismoInvalido = Argon2Params(
          memoryKib: fastParams.memoryKib,
          iterations: fastParams.iterations,
          parallelism: 4,
        );

        await expectLater(
          adapter.deriveKey(
            masterPassword: 'da igual',
            salt: salt,
            params: paramsConParalelismoInvalido,
          ),
          throwsA(isA<ArgumentError>()),
        );
      },
    );
  });

  group('SodiumCryptoAdapter — XChaCha20-Poly1305 (encrypt/decrypt)', () {
    test('round-trip: decrypt(encrypt(x)) == x', () async {
      final key = Uint8List.fromList(
        utf8.encode('01234567890123456789012345678901'), // 32 bytes
      );
      final plaintext = Uint8List.fromList(utf8.encode('secreto de prueba'));
      final aad = Uint8List.fromList(utf8.encode('header de prueba'));

      final encrypted = await adapter.encrypt(
        key: key,
        plaintext: plaintext,
        aad: aad,
      );
      final decrypted = await adapter.decrypt(
        key: key,
        payload: encrypted,
        aad: aad,
      );

      expect(decrypted, equals(plaintext));
    });

    test('falla si el AAD fue manipulado', () async {
      final key = Uint8List.fromList(
        utf8.encode('01234567890123456789012345678901'),
      );
      final plaintext = Uint8List.fromList(utf8.encode('secreto de prueba'));
      final aad = Uint8List.fromList(utf8.encode('header original'));
      final aadManipulado = Uint8List.fromList(utf8.encode('header alterado'));

      final encrypted = await adapter.encrypt(
        key: key,
        plaintext: plaintext,
        aad: aad,
      );

      await expectLater(
        adapter.decrypt(key: key, payload: encrypted, aad: aadManipulado),
        throwsA(isA<SodiumException>()),
      );
    });

    test('falla si el ciphertext fue manipulado', () async {
      final key = Uint8List.fromList(
        utf8.encode('01234567890123456789012345678901'),
      );
      final plaintext = Uint8List.fromList(utf8.encode('secreto de prueba'));
      final aad = Uint8List.fromList(utf8.encode('header'));

      final encrypted = await adapter.encrypt(
        key: key,
        plaintext: plaintext,
        aad: aad,
      );
      final ciphertextManipulado = Uint8List.fromList(encrypted.ciphertext);
      ciphertextManipulado[0] ^= 0xFF;

      await expectLater(
        adapter.decrypt(
          key: key,
          payload: EncryptedPayload(
            nonce: encrypted.nonce,
            ciphertext: ciphertextManipulado,
          ),
          aad: aad,
        ),
        throwsA(isA<SodiumException>()),
      );
    });
  });
}
