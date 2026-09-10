// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Lockspire

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:lockspire/features/vault/domain/ports/vault_storage_port.dart';
import 'package:lockspire/features/vault/domain/vault_file_codec.dart';

VaultFile _fileWithPayload(List<int> payload) {
  return VaultFile(
    header: VaultHeader(
      formatVersion: 1,
      formatMinReaderVersion: 1,
      salt: Uint8List.fromList(List.filled(16, 1)),
      nonce: Uint8List.fromList(List.filled(24, 2)),
      vaultId: 'vault-1',
      createdAt: DateTime.utc(2026),
      kdfParams: const Argon2Params(
        memoryKib: 524288,
        iterations: 4,
        parallelism: 1,
      ),
    ),
    encryptedPayload: Uint8List.fromList(payload),
  );
}

void main() {
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
