// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Lockspire

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lockspire/features/vault/application/create_vault_use_case.dart';
import 'package:lockspire/features/vault/application/unlock_vault_use_case.dart';
import 'package:lockspire/features/vault/infrastructure/atomic_file_vault_storage_adapter.dart';
import 'package:lockspire/features/vault/infrastructure/sodium_crypto_adapter.dart';
import 'package:sodium/sodium_sumo.dart';

/// Test de integración de punta a punta con los adaptadores REALES (no
/// fakes): crear bóveda → escribir a disco → leer de disco → desbloquear.
///
/// Cada adaptador tiene sus propios tests aislados (sodium_crypto_adapter_test
/// y atomic_file_vault_storage_adapter_test), pero ninguno de los dos por sí
/// solo prueba que la construcción del AAD (VaultHeader.toAadBytes) sea
/// idéntica byte a byte en el momento de escribir y en el de leer — si un
/// adaptador la reconstruyera de forma sutilmente distinta, cada test
/// aislado podría seguir pasando y el sistema completo aun así no lograr
/// desbloquear su propia bóveda. Este test es el que conecta las piezas.
void main() {
  late Directory tempDir;
  late SodiumSumo sodium;

  setUpAll(() async {
    sodium = await SodiumSumoInit.init();
  });

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('lockspire_roundtrip_');
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('CreateVaultUseCase + UnlockVaultUseCase con adaptadores reales: '
      'crear → escribir → leer → desbloquear', () async {
    final path = '${tempDir.path}/vault.lockspire';
    final crypto = SodiumCryptoAdapter(sodium);
    final storage = AtomicFileVaultStorageAdapter(path);
    const masterPassword = 'correcto-caballo-batería-grapa';

    final created = await CreateVaultUseCase(storage: storage, crypto: crypto)(
      masterPassword: masterPassword,
    );

    // El archivo debe existir de verdad en disco tras CreateVaultUseCase.
    expect(await File(path).exists(), isTrue);

    final unlocked = await UnlockVaultUseCase(storage: storage, crypto: crypto)(
      masterPassword: masterPassword,
    );

    expect(unlocked.vaultId, created.vaultId);
    expect(unlocked.schemaVersion, created.schemaVersion);
    expect(unlocked.entries, isEmpty);
    expect(unlocked.folders, isEmpty);
  });

  test(
    'UnlockVaultUseCase falla con la contraseña maestra incorrecta',
    () async {
      final path = '${tempDir.path}/vault.lockspire';
      final crypto = SodiumCryptoAdapter(sodium);
      final storage = AtomicFileVaultStorageAdapter(path);

      await CreateVaultUseCase(storage: storage, crypto: crypto)(
        masterPassword: 'contraseña-correcta',
      );

      await expectLater(
        UnlockVaultUseCase(storage: storage, crypto: crypto)(
          masterPassword: 'contraseña-incorrecta',
        ),
        throwsA(isA<SodiumException>()),
      );
    },
  );
}
