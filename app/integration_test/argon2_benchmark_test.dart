// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Lockspire

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:lockspire/features/vault/application/create_vault_use_case.dart';
import 'package:lockspire/features/vault/domain/ports/argon2_params.dart';
import 'package:lockspire/features/vault/infrastructure/sodium_crypto_adapter.dart';
import 'package:sodium/sodium_sumo.dart';

/// Benchmark real de Argon2id en el dispositivo de pruebas — pendiente
/// desde docs/adr/0002-motor-criptografico.md y docs/adr/0007-paralelismo-argon2id-libsodium.md.
///
/// Corre EN el dispositivo (no en el host), a diferencia de `flutter test`:
/// `flutter test integration_test/argon2_benchmark_test.dart -d DEVICE_ID`
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'Argon2id — defaultArgon2Params (512 MiB, 4 iter, paralelismo 1)',
    (tester) async {
      final sodium = await SodiumSumoInit.init();
      final adapter = SodiumCryptoAdapter(sodium);
      final salt = adapter.generateSalt();

      final stopwatch = Stopwatch()..start();
      await adapter.deriveKey(
        masterPassword: 'correcto-caballo-batería-grapa',
        salt: salt,
        params: defaultArgon2Params,
      );
      stopwatch.stop();

      // ignore: avoid_print
      print(
        'BENCHMARK Argon2id defaultArgon2Params: '
        '${stopwatch.elapsedMilliseconds} ms '
        '(memoria=${defaultArgon2Params.memoryKib} KiB, '
        'iteraciones=${defaultArgon2Params.iterations}, '
        'paralelismo=${defaultArgon2Params.parallelism})',
      );

      // No fijamos un límite estricto aquí (el benchmark es informativo, no
      // un gate de CI) — el resultado se registra en docs/STATE.md para
      // decidir si los parámetros por defecto son aceptables en UX.
    },
  );

  testWidgets(
    'Argon2id — mínimos de ADR 0002 (256 MiB, 3 iter, paralelismo 1)',
    (tester) async {
      final sodium = await SodiumSumoInit.init();
      final adapter = SodiumCryptoAdapter(sodium);
      final salt = adapter.generateSalt();
      const minParams = Argon2Params(
        memoryKib: 262144,
        iterations: 3,
        parallelism: 1,
      );

      final stopwatch = Stopwatch()..start();
      await adapter.deriveKey(
        masterPassword: 'correcto-caballo-batería-grapa',
        salt: salt,
        params: minParams,
      );
      stopwatch.stop();

      // ignore: avoid_print
      print(
        'BENCHMARK Argon2id minParams (ADR 0002): '
        '${stopwatch.elapsedMilliseconds} ms',
      );
    },
  );
}
