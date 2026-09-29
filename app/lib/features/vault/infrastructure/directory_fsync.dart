// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Gabriel Ángel Montoya Rico

import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';

typedef _OpenNative = Int32 Function(Pointer<Utf8> path, Int32 flags);
typedef _Open = int Function(Pointer<Utf8> path, int flags);
typedef _FdNative = Int32 Function(Int32 fd);
typedef _Fd = int Function(int fd);

const _oRdOnly = 0;

/// `fsync` de un directorio (revisión 2026-09-25, hallazgo S12).
///
/// En Linux y Android, `rename` es atómico, pero la entrada nueva del
/// directorio puede quedar solo en caché: ante un corte de luz justo
/// después de guardar, el directorio podría seguir apuntando al archivo
/// anterior. Sincronizar el directorio después del `rename` lo hace
/// durable. `dart:io` no permite abrir un directorio, de ahí el FFI.
///
/// Es **best-effort**: si el sistema de archivos no lo soporta o falla, no
/// se lanza. El archivo nuevo ya está escrito, sincronizado y renombrado,
/// y reportar un error haría creer que el guardado falló cuando no fue
/// así. En Windows no hace nada (ahí el `rename` no expone este paso).
void fsyncDirectory(String directoryPath) {
  if (!(Platform.isLinux || Platform.isAndroid)) return;
  try {
    final libc = DynamicLibrary.process();
    final open = libc.lookupFunction<_OpenNative, _Open>('open');
    final fsync = libc.lookupFunction<_FdNative, _Fd>('fsync');
    final close = libc.lookupFunction<_FdNative, _Fd>('close');

    final fd = using(
      (arena) => open(directoryPath.toNativeUtf8(allocator: arena), _oRdOnly),
    );
    if (fd < 0) return;
    try {
      fsync(fd);
    } finally {
      close(fd);
    }
  } catch (_) {
    // Best-effort, ver arriba.
  }
}
