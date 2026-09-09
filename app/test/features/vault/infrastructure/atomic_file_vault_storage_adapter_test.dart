// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Lockspire

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:lockspire/features/vault/domain/ports/vault_storage_port.dart';
import 'package:lockspire/features/vault/infrastructure/atomic_file_vault_storage_adapter.dart';

VaultHeader _sampleHeader({int formatMinReaderVersion = 1}) {
  return VaultHeader(
    formatVersion: 1,
    formatMinReaderVersion: formatMinReaderVersion,
    salt: Uint8List.fromList(List.filled(16, 1)),
    nonce: Uint8List.fromList(List.filled(24, 2)),
    vaultId: 'vault-de-prueba',
    createdAt: DateTime.utc(2026, 1, 1),
    kdfParams: const Argon2Params(
      memoryKib: 65536,
      iterations: 3,
      parallelism: 1,
    ),
  );
}

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('lockspire_vault_test_');
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('AtomicFileVaultStorageAdapter', () {
    test('write + read: round-trip conserva header y payload', () async {
      final path = '${tempDir.path}/vault.lockspire';
      final adapter = AtomicFileVaultStorageAdapter(path);
      final header = _sampleHeader();
      final payload = Uint8List.fromList(utf8.encode('ciphertext-de-prueba'));

      await adapter.write(VaultFile(header: header, encryptedPayload: payload));
      final read = await adapter.read();

      expect(read.header.vaultId, header.vaultId);
      expect(read.header.formatVersion, header.formatVersion);
      expect(read.header.formatMinReaderVersion, header.formatMinReaderVersion);
      expect(read.header.salt, header.salt);
      expect(read.header.nonce, header.nonce);
      expect(read.header.kdfParams.memoryKib, header.kdfParams.memoryKib);
      // El parallelism leído de vuelta del header persistido en disco debe
      // ser exactamente el que se escribió — no un valor distinto (ver
      // docs/adr/0007-paralelismo-argon2id-libsodium.md).
      expect(read.header.kdfParams.parallelism, 1);
      expect(read.encryptedPayload, payload);
    });

    test('no deja archivo temporal huérfano tras un write exitoso', () async {
      final path = '${tempDir.path}/vault.lockspire';
      final adapter = AtomicFileVaultStorageAdapter(path);

      await adapter.write(
        VaultFile(
          header: _sampleHeader(),
          encryptedPayload: Uint8List.fromList([1, 2, 3]),
        ),
      );

      final entries = await tempDir.list().toList();
      final tempFiles = entries.where((e) => e.path.contains('.tmp-'));
      expect(tempFiles, isEmpty);
    });

    test('exists() refleja si el archivo fue escrito', () async {
      final path = '${tempDir.path}/vault.lockspire';
      final adapter = AtomicFileVaultStorageAdapter(path);

      expect(await adapter.exists(), isFalse);

      await adapter.write(
        VaultFile(
          header: _sampleHeader(),
          encryptedPayload: Uint8List.fromList([1]),
        ),
      );

      expect(await adapter.exists(), isTrue);
    });

    test(
      'rechaza explícitamente un formato futuro no soportado (nunca degrada en silencio)',
      () async {
        final path = '${tempDir.path}/vault.lockspire';
        final adapter = AtomicFileVaultStorageAdapter(path);

        await adapter.write(
          VaultFile(
            header: _sampleHeader(formatMinReaderVersion: 999),
            encryptedPayload: Uint8List.fromList([1]),
          ),
        );

        await expectLater(
          adapter.read(),
          throwsA(isA<UnsupportedVaultFormatException>()),
        );
      },
    );
  });
}
