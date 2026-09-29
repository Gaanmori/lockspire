// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Gabriel Ángel Montoya Rico

import 'dart:io';

import 'package:path/path.dart' as p;

import 'posix_ffi.dart' as posix;
import 'win32_ffi.dart' as win32;

/// Dónde vive el canal IPC y su token (ADR 0013).
class IpcLocation {
  /// Named pipe (`\\.\pipe\...`) en Windows, ruta del socket en Linux.
  final String endpoint;
  final String tokenPath;
  final String directory;

  const IpcLocation({
    required this.endpoint,
    required this.tokenPath,
    required this.directory,
  });

  /// Ubicación por defecto para el usuario actual.
  factory IpcLocation.forCurrentUser() {
    if (Platform.isWindows) {
      final localAppData = Platform.environment['LOCALAPPDATA'];
      if (localAppData == null || localAppData.isEmpty) {
        throw StateError('LOCALAPPDATA no está definido');
      }
      final dir = p.join(localAppData, 'Lockspire', 'ipc');
      return IpcLocation(
        endpoint: r'\\.\pipe\lockspire-ipc-' + win32.currentUserSid(),
        tokenPath: p.join(dir, 'ipc.token'),
        directory: dir,
      );
    }
    if (Platform.isLinux) {
      final runtimeDir = Platform.environment['XDG_RUNTIME_DIR'];
      // Sin fallback a /tmp a propósito: ahí otro usuario podría
      // pre-crear el directorio (ADR 0013).
      if (runtimeDir == null || runtimeDir.isEmpty) {
        throw StateError('XDG_RUNTIME_DIR no está definido');
      }
      final dir = p.join(runtimeDir, 'lockspire');
      return IpcLocation(
        endpoint: p.join(dir, 'ipc.sock'),
        tokenPath: p.join(dir, 'ipc.token'),
        directory: dir,
      );
    }
    throw UnsupportedError('IPC no soportado en ${Platform.operatingSystem}');
  }

  /// Crea [directory] si hace falta. En Linux además exige que el
  /// directorio padre (`$XDG_RUNTIME_DIR`) sea privado (`0700`) y fija el
  /// propio a `0700`.
  void ensureDirectory() {
    final dir = Directory(directory);
    if (Platform.isLinux) {
      final parentMode = FileStat.statSync(dir.parent.path).mode & 0x1FF;
      if (parentMode != 0x1C0) {
        throw StateError(
          '${dir.parent.path} debe tener permisos 0700 '
          '(tiene ${parentMode.toRadixString(8)})',
        );
      }
    }
    dir.createSync(recursive: true);
    if (Platform.isLinux) posix.chmod(directory, 0x1C0); // 0700
  }
}
