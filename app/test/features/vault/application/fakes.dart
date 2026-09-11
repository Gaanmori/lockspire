// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Lockspire

import 'dart:convert';
import 'dart:typed_data';

import 'package:lockspire/features/vault/domain/ports/biometric_auth_port.dart';
import 'package:lockspire/features/vault/domain/ports/crypto_port.dart';
import 'package:lockspire/features/vault/domain/ports/vault_storage_port.dart';

/// Cripto falsa para tests: "cifra" con un XOR trivial reversible y verifica
/// el AAD por igualdad exacta. No usar fuera de tests — no es criptografía
/// real, solo permite probar el flujo de los casos de uso contra los
/// puertos sin depender de libsodium.
class FakeCryptoPort implements CryptoPort {
  int saltCounter = 0;
  int deriveKeyCalls = 0;

  @override
  Uint8List generateSalt() {
    saltCounter++;
    return Uint8List.fromList(List.filled(16, saltCounter));
  }

  @override
  Future<Uint8List> deriveKey({
    required String masterPassword,
    required Uint8List salt,
    required Argon2Params params,
  }) async {
    deriveKeyCalls++;
    if (params.parallelism != 1) {
      throw ArgumentError.value(
        params.parallelism,
        'params.parallelism',
        'debe ser 1 (ver ADR 0007)',
      );
    }
    return Uint8List.fromList(utf8.encode(masterPassword));
  }

  @override
  Future<EncryptedPayload> encrypt({
    required Uint8List key,
    required Uint8List plaintext,
    required Uint8List aad,
  }) async {
    final nonce = Uint8List.fromList(List.filled(24, 7));
    final ciphertext = _xor(plaintext, key);
    return EncryptedPayload(
      nonce: nonce,
      ciphertext: Uint8List.fromList([...ciphertext, ..._tagFor(aad, key)]),
    );
  }

  @override
  Future<Uint8List> decrypt({
    required Uint8List key,
    required EncryptedPayload payload,
    required Uint8List aad,
  }) async {
    final tagLen = _tagFor(aad, key).length;
    final ciphertext = payload.ciphertext.sublist(
      0,
      payload.ciphertext.length - tagLen,
    );
    final tag = payload.ciphertext.sublist(payload.ciphertext.length - tagLen);
    final expectedTag = _tagFor(aad, key);
    if (!_bytesEqual(tag, expectedTag)) {
      throw StateError('Fallo de autenticación (AAD o clave incorrectos)');
    }
    return _xor(ciphertext, key);
  }

  Uint8List _xor(Uint8List data, Uint8List key) {
    return Uint8List.fromList([
      for (var i = 0; i < data.length; i++) data[i] ^ key[i % key.length],
    ]);
  }

  Uint8List _tagFor(Uint8List aad, Uint8List key) {
    // "Tag" determinista y trivial (no criptográfico) para detectar en
    // tests si el AAD o la clave no coinciden.
    final sum = [...aad, ...key].fold<int>(0, (acc, b) => (acc + b) % 256);
    return Uint8List.fromList(List.filled(8, sum));
  }

  bool _bytesEqual(Uint8List a, Uint8List b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

/// Storage en memoria para tests — no toca disco.
class FakeVaultStoragePort implements VaultStoragePort {
  VaultFile? stored;

  @override
  Future<bool> exists() async => stored != null;

  @override
  Future<VaultFile> read() async {
    final file = stored;
    if (file == null) {
      throw StateError('No hay bóveda almacenada');
    }
    return file;
  }

  @override
  Future<void> write(VaultFile file) async {
    stored = file;
  }
}

/// Biometría falsa para tests — sin platform channels reales. [available]
/// controla lo que devuelve [checkAvailability]; [nextReadKeyResult]
/// controla lo que [readKey] devuelve la próxima vez que se llame (`null`
/// simula que el usuario canceló/falló el prompt, ver el contrato de
/// [BiometricAuthPort.readKey]).
class FakeBiometricAuthPort implements BiometricAuthPort {
  BiometricAvailability available = BiometricAvailability.available;
  Uint8List? nextReadKeyResult;
  Uint8List? _storedKey;
  bool _onboardingDismissed = false;

  @override
  Future<BiometricAvailability> checkAvailability() async => available;

  @override
  Future<bool> hasStoredKey() async => _storedKey != null;

  @override
  Future<void> storeKey({required Uint8List key}) async {
    _storedKey = key;
  }

  @override
  Future<Uint8List?> readKey() async => nextReadKeyResult;

  @override
  Future<void> deleteKey() async {
    _storedKey = null;
  }

  @override
  Future<bool> wasOnboardingDismissed() async => _onboardingDismissed;

  @override
  Future<void> markOnboardingDismissed() async {
    _onboardingDismissed = true;
  }
}
