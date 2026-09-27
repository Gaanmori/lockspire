// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Lockspire

import 'dart:io';

import 'package:path/path.dart' as p;

import '../domain/ports/vault_storage_port.dart';
import '../domain/vault_file_codec.dart';
import 'directory_fsync.dart';

export '../domain/vault_file_codec.dart' show UnsupportedVaultFormatException;

/// Implementación de [VaultStoragePort] sobre `dart:io`.
///
/// El framing binario del archivo (ver docs/adr/0004-formato-boveda-v1.md)
/// vive en [VaultFileCodec], compartido con cualquier otro adaptador que
/// necesite mover los mismos bytes (ej. sync remoto).
///
/// La escritura es siempre atómica (temporal + fsync + rename, nunca
/// sobrescritura en sitio) — regla fijada en CLAUDE.md — y, en Linux y
/// Android, durable también ante un corte de luz: después del rename se
/// sincroniza el directorio ([fsyncDirectory], hallazgo S12).
class AtomicFileVaultStorageAdapter implements VaultStoragePort {
  final String path;

  const AtomicFileVaultStorageAdapter(this.path);

  @override
  Future<bool> exists() => File(path).exists();

  @override
  Future<VaultFile> read() async {
    final bytes = await File(path).readAsBytes();
    return VaultFileCodec.decode(bytes);
  }

  @override
  Future<void> write(VaultFile file) async {
    final bytes = VaultFileCodec.encode(file);

    final target = File(path);
    final tempPath = '$path.tmp-${DateTime.now().microsecondsSinceEpoch}';
    final tempFile = File(tempPath);

    final raf = await tempFile.open(mode: FileMode.writeOnly);
    try {
      await raf.writeFrom(bytes);
      await raf.flush(); // fsync (POSIX) / FlushFileBuffers (Windows)
    } finally {
      await raf.close();
    }

    // Rename atómico al path final — nunca sobrescritura en sitio.
    await tempFile.rename(target.path);
    fsyncDirectory(p.dirname(target.absolute.path));
  }
}
