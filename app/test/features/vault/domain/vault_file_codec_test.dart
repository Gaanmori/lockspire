// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Gabriel Ángel Montoya Rico

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:lockspire/shared/domain/app_problem.dart';
import 'package:lockspire/features/vault/domain/ports/vault_storage_port.dart';
import 'package:lockspire/features/vault/domain/vault_file_codec.dart';

VaultFile _fileWithPayload(
  List<int> payload, {
  Argon2Params kdf = const Argon2Params(
    memoryKib: 524288,
    iterations: 4,
    parallelism: 1,
  ),
}) {
  return VaultFile(
    header: VaultHeader(
      formatVersion: 1,
      formatMinReaderVersion: 1,
      salt: Uint8List.fromList(List.filled(16, 1)),
      nonce: Uint8List.fromList(List.filled(24, 2)),
      vaultId: 'vault-1',
      createdAt: DateTime.utc(2026),
      kdfParams: kdf,
    ),
    encryptedPayload: Uint8List.fromList(payload),
  );
}

void main() {
  // Revisión 2026-09-25: S3 (parámetros de Argon2id sin límites) y S11
  // (errores crudos con archivos malformados).
  group('VaultFileCodec.decode — archivos malformados o hostiles', () {
    test('ida y vuelta de un archivo válido', () {
      final file = _fileWithPayload([9, 9, 9]);
      final decoded = VaultFileCodec.decode(VaultFileCodec.encode(file));
      expect(decoded.encryptedPayload, [9, 9, 9]);
      expect(decoded.header.vaultId, 'vault-1');
    });

    test('truncado, longitud de header imposible o JSON roto → '
        'FormatException (nunca RangeError/TypeError)', () {
      final valid = VaultFileCodec.encode(_fileWithPayload([1]));
      final cases = <String, Uint8List>{
        'vacío': Uint8List(0),
        'solo magic': Uint8List.fromList(valid.sublist(0, 4)),
        'header cortado': Uint8List.fromList(valid.sublist(0, 20)),
        'headerLen enorme': Uint8List.fromList(valid)
          ..setRange(6, 10, [0xFF, 0xFF, 0xFF, 0xFF]),
        'header no es JSON': Uint8List.fromList([
          ...valid.sublist(0, 6),
          0,
          0,
          0,
          3,
          ...'{x!'.codeUnits,
        ]),
      };
      for (final MapEntry(key: name, value: bytes) in cases.entries) {
        expect(
          () => VaultFileCodec.decode(bytes),
          throwsA(isA<AppProblem>()),
          reason: name,
        );
      }
    });

    test(
      'parámetros de Argon2id fuera de límites → UnsafeKdfParamsException',
      () {
        const hostile = {
          '64 GiB': Argon2Params(
            memoryKib: 64 * 1024 * 1024,
            iterations: 4,
            parallelism: 1,
          ),
          'mil millones de iteraciones': Argon2Params(
            memoryKib: 524288,
            iterations: 1000000000,
            parallelism: 1,
          ),
          'por debajo del mínimo de ADR 0002': Argon2Params(
            memoryKib: 65536,
            iterations: 3,
            parallelism: 1,
          ),
          'cero iteraciones': Argon2Params(
            memoryKib: 524288,
            iterations: 0,
            parallelism: 1,
          ),
          'paralelismo 4 (ADR 0007)': Argon2Params(
            memoryKib: 524288,
            iterations: 4,
            parallelism: 4,
          ),
        };
        for (final MapEntry(key: name, value: kdf) in hostile.entries) {
          final bytes = VaultFileCodec.encode(_fileWithPayload([1], kdf: kdf));
          expect(
            () => VaultFileCodec.decode(bytes),
            throwsA(isA<UnsafeKdfParamsException>()),
            reason: name,
          );
        }
      },
    );

    test('los valores por defecto y los límites exactos se aceptan', () {
      for (final kdf in const [
        Argon2Params(memoryKib: 524288, iterations: 4, parallelism: 1),
        Argon2Params(
          memoryKib: Argon2Params.minMemoryKib,
          iterations: Argon2Params.minIterations,
          parallelism: 1,
        ),
        Argon2Params(
          memoryKib: Argon2Params.maxMemoryKib,
          iterations: Argon2Params.maxIterations,
          parallelism: 1,
        ),
      ]) {
        final bytes = VaultFileCodec.encode(_fileWithPayload([1], kdf: kdf));
        expect(
          VaultFileCodec.decode(bytes).header.kdfParams.memoryKib,
          kdf.memoryKib,
        );
      }
    });
  });

  group('VaultFileCodec.sha256Hex', () {
    test('es determinista para el mismo VaultFile', () {
      final file = _fileWithPayload([1, 2, 3]);

      expect(
        VaultFileCodec.sha256Hex(file),
        VaultFileCodec.sha256Hex(_fileWithPayload([1, 2, 3])),
      );
    });

    test('cambia si cambia el payload', () {
      final a = _fileWithPayload([1, 2, 3]);
      final b = _fileWithPayload([1, 2, 4]);

      expect(VaultFileCodec.sha256Hex(a), isNot(VaultFileCodec.sha256Hex(b)));
    });
  });
}
