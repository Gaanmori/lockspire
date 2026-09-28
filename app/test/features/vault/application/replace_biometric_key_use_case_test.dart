// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Lockspire

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:lockspire/features/vault/application/replace_biometric_key_use_case.dart';

import 'fakes.dart';

/// Registra el orden de llamadas y puede fallar al guardar.
class _RecordingPort extends FakeBiometricAuthPort {
  final calls = <String>[];
  bool failStore = false;

  @override
  Future<void> storeKey({required Uint8List key}) async {
    calls.add('store');
    if (failStore) throw Exception('keystore');
    await super.storeKey(key: key);
  }

  @override
  Future<void> deleteKey() async {
    calls.add('delete');
    await super.deleteKey();
  }
}

void main() {
  final oldKey = Uint8List.fromList([1, 2, 3]);
  final newKey = Uint8List.fromList([4, 5, 6]);

  test('con biometría activa, sobrescribe la clave sin borrarla antes: '
      'nunca hay un momento sin biometría configurada', () async {
    final port = _RecordingPort();
    await port.storeKey(key: oldKey);
    port.calls.clear();

    await ReplaceBiometricKeyUseCase(port).call(newKey);

    expect(port.calls, ['store']);
    expect(await port.hasStoredKey(), isTrue);
  });

  test('si guardar la nueva falla, se borra: nunca queda una clave que no '
      'abre la bóveda', () async {
    final port = _RecordingPort();
    await port.storeKey(key: oldKey);
    port
      ..calls.clear()
      ..failStore = true;

    await ReplaceBiometricKeyUseCase(port).call(newKey);

    expect(port.calls, ['store', 'delete']);
    expect(await port.hasStoredKey(), isFalse);
  });

  test('sin biometría activa no la activa', () async {
    final port = _RecordingPort();
    await ReplaceBiometricKeyUseCase(port).call(newKey);
    expect(port.calls, isEmpty);
    expect(await port.hasStoredKey(), isFalse);
  });
}
