// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Gabriel Ángel Montoya Rico

// Bindings FFI mínimos a libc (Linux). `dart:io` no permite fijar permisos
// de archivos ni leer el uid propio.

import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';

final _libc = DynamicLibrary.process();

final _getuid = _libc.lookupFunction<Uint32 Function(), int Function()>(
  'getuid',
);

final _chmod = _libc
    .lookupFunction<
      Int32 Function(Pointer<Utf8>, Uint32),
      int Function(Pointer<Utf8>, int)
    >('chmod');

int currentUid() => _getuid();

/// `chmod(path, mode)`. Lanza si falla — un permiso que no se pudo fijar
/// es un error de seguridad, no algo que ignorar.
void chmod(String path, int mode) {
  final result = using(
    (arena) => _chmod(path.toNativeUtf8(allocator: arena), mode),
  );
  if (result != 0) {
    throw FileSystemException('chmod ${mode.toRadixString(8)} falló', path);
  }
}

const _solSocket = 1;
const _soPeercred = 17;

/// uid del proceso al otro lado de un socket Unix (`SO_PEERCRED`,
/// `struct ucred { pid_t pid; uid_t uid; gid_t gid; }`).
int peerUid(Socket socket) {
  final raw = socket.getRawOption(
    RawSocketOption(_solSocket, _soPeercred, Uint8List(12)),
  );
  return ByteData.sublistView(raw).getUint32(4, Endian.host);
}
