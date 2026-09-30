// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Gabriel Ángel Montoya Rico

import 'dart:typed_data';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lockspire/features/vault/domain/ports/biometric_auth_port.dart';
import 'package:lockspire/features/vault/infrastructure/android_biometric_auth_adapter.dart';
import 'package:lockspire/features/vault/infrastructure/unavailable_biometric_auth_adapter.dart';
import 'package:lockspire/features/vault/infrastructure/windows_biometric_auth_adapter.dart';

import '../../../support/fakes/fake_local_authentication.dart';

typedef _Build =
    BiometricAuthPort Function(
      FlutterSecureStorage storage,
      FakeLocalAuthentication localAuth,
    );

/// La clave de la bóveda detrás de la huella o Windows Hello (ADR 0010):
/// el mismo contrato en Android y en Windows. Solo se entrega después de
/// que el sistema verificó a la persona.
void main() {
  final key = Uint8List.fromList(List.generate(32, (i) => i));
  const storage = FlutterSecureStorage();
  late Map<String, String> stored;

  setUp(() {
    stored = {};
    FlutterSecureStorage.setMockInitialValues(stored);
  });

  final adapters = <String, _Build>{
    'Android': (storage, localAuth) => AndroidBiometricAuthAdapter(
      storage: storage,
      promptReason: 'Verifíquese',
      localAuth: localAuth,
    ),
    'Windows': (storage, localAuth) => WindowsBiometricAuthAdapter(
      storage: storage,
      promptReason: 'Verifíquese',
      localAuth: localAuth,
    ),
  };

  for (final MapEntry(key: platform, value: build) in adapters.entries) {
    group(platform, () {
      test('guarda la clave y la entrega solo tras verificar', () async {
        final localAuth = FakeLocalAuthentication();
        final adapter = build(storage, localAuth);
        expect(await adapter.hasStoredKey(), isFalse);

        await adapter.storeKey(key: key);

        expect(await adapter.hasStoredKey(), isTrue);
        expect(
          stored.values.single,
          isNot(contains(String.fromCharCodes(key))),
        );
        expect(await adapter.readKey(), key);
        expect(localAuth.authenticateCalled, isTrue);
      });

      test('verificada pero sin clave guardada: nada', () async {
        expect(
          await build(storage, FakeLocalAuthentication()).readKey(),
          isNull,
        );
      });

      test('desactivar borra la clave', () async {
        final adapter = build(storage, FakeLocalAuthentication());
        await adapter.storeKey(key: key);

        await adapter.deleteKey();

        expect(await adapter.hasStoredKey(), isFalse);
        expect(stored, isEmpty);
      });

      test('"Ahora no" se recuerda', () async {
        final adapter = build(storage, FakeLocalAuthentication());
        expect(await adapter.wasOnboardingDismissed(), isFalse);

        await adapter.markOnboardingDismissed();

        expect(await adapter.wasOnboardingDismissed(), isTrue);
      });
    });
  }

  test('en Android, un intento anterior colgado no impide pedir la '
      'huella', () async {
    final localAuth = FakeLocalAuthentication()..stopError = StateError('x');
    final adapter = adapters['Android']!(storage, localAuth);
    await adapter.storeKey(key: key);

    expect(await adapter.readKey(), key);
  });

  test('sin biometría en la plataforma: nunca guarda ni entrega nada, y no '
      'la ofrece', () async {
    const adapter = UnavailableBiometricAuthAdapter();

    await adapter.storeKey(key: key);
    await adapter.markOnboardingDismissed();
    await adapter.deleteKey();

    expect(
      await adapter.checkAvailability(),
      BiometricAvailability.unavailable,
    );
    expect(await adapter.hasStoredKey(), isFalse);
    expect(await adapter.readKey(), isNull);
    expect(await adapter.wasOnboardingDismissed(), isTrue);
  });
}
