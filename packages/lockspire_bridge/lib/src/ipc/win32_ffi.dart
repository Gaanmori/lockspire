// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Lockspire

// Bindings FFI mínimos a Win32 para el named pipe de ADR 0013. Se escriben
// a mano (en vez de depender de package:win32) para que la superficie sea
// exactamente la que se usa y quepa en una revisión.
//
// Ninguna función se declara `isLeaf`: varias bloquean (ConnectNamedPipe,
// ReadFile) y una llamada leaf bloqueante impide los safepoints del GC en
// todo el grupo de isolates, congelando la app.

import 'dart:ffi';

import 'package:ffi/ffi.dart';

final _kernel32 = DynamicLibrary.open('kernel32.dll');
final _advapi32 = DynamicLibrary.open('advapi32.dll');

const invalidHandleValue = -1;

const pipeAccessDuplex = 0x00000003;
const fileFlagFirstPipeInstance = 0x00080000;
const pipeTypeByte = 0x00000000;
const pipeReadmodeByte = 0x00000000;
const pipeWait = 0x00000000;
const pipeRejectRemoteClients = 0x00000008;
const pipeUnlimitedInstances = 255;
const genericRead = 0x80000000;
const genericWrite = 0x40000000;
const openExisting = 3;
const securitySqosPresent = 0x00100000;
const securityIdentification = 0x00010000;
const tokenQuery = 0x0008;
const tokenUserClass = 1;
const processQueryLimitedInformation = 0x1000;
const sddlRevision1 = 1;

final class SecurityAttributes extends Struct {
  @Uint32()
  external int nLength;
  external Pointer<Void> lpSecurityDescriptor;
  @Int32()
  external int bInheritHandle;
}

final createNamedPipe = _kernel32
    .lookupFunction<
      IntPtr Function(
        Pointer<Utf16>,
        Uint32,
        Uint32,
        Uint32,
        Uint32,
        Uint32,
        Uint32,
        Pointer<SecurityAttributes>,
      ),
      int Function(
        Pointer<Utf16>,
        int,
        int,
        int,
        int,
        int,
        int,
        Pointer<SecurityAttributes>,
      )
    >('CreateNamedPipeW');

final connectNamedPipe = _kernel32
    .lookupFunction<
      Int32 Function(IntPtr, Pointer<Void>),
      int Function(int, Pointer<Void>)
    >('ConnectNamedPipe');

final disconnectNamedPipe = _kernel32
    .lookupFunction<Int32 Function(IntPtr), int Function(int)>(
      'DisconnectNamedPipe',
    );

final waitNamedPipe = _kernel32
    .lookupFunction<
      Int32 Function(Pointer<Utf16>, Uint32),
      int Function(Pointer<Utf16>, int)
    >('WaitNamedPipeW');

final createFile = _kernel32
    .lookupFunction<
      IntPtr Function(
        Pointer<Utf16>,
        Uint32,
        Uint32,
        Pointer<Void>,
        Uint32,
        Uint32,
        IntPtr,
      ),
      int Function(Pointer<Utf16>, int, int, Pointer<Void>, int, int, int)
    >('CreateFileW');

final readFile = _kernel32
    .lookupFunction<
      Int32 Function(
        IntPtr,
        Pointer<Uint8>,
        Uint32,
        Pointer<Uint32>,
        Pointer<Void>,
      ),
      int Function(int, Pointer<Uint8>, int, Pointer<Uint32>, Pointer<Void>)
    >('ReadFile');

final writeFile = _kernel32
    .lookupFunction<
      Int32 Function(
        IntPtr,
        Pointer<Uint8>,
        Uint32,
        Pointer<Uint32>,
        Pointer<Void>,
      ),
      int Function(int, Pointer<Uint8>, int, Pointer<Uint32>, Pointer<Void>)
    >('WriteFile');

final flushFileBuffers = _kernel32
    .lookupFunction<Int32 Function(IntPtr), int Function(int)>(
      'FlushFileBuffers',
    );

final closeHandle = _kernel32
    .lookupFunction<Int32 Function(IntPtr), int Function(int)>('CloseHandle');

final getNamedPipeServerProcessId = _kernel32
    .lookupFunction<
      Int32 Function(IntPtr, Pointer<Uint32>),
      int Function(int, Pointer<Uint32>)
    >('GetNamedPipeServerProcessId');

final getNamedPipeClientProcessId = _kernel32
    .lookupFunction<
      Int32 Function(IntPtr, Pointer<Uint32>),
      int Function(int, Pointer<Uint32>)
    >('GetNamedPipeClientProcessId');

final openProcess = _kernel32
    .lookupFunction<
      IntPtr Function(Uint32, Int32, Uint32),
      int Function(int, int, int)
    >('OpenProcess');

final getCurrentProcess = _kernel32
    .lookupFunction<IntPtr Function(), int Function()>('GetCurrentProcess');

final localFree = _kernel32
    .lookupFunction<
      IntPtr Function(Pointer<Void>),
      int Function(Pointer<Void>)
    >('LocalFree');

final openProcessToken = _advapi32
    .lookupFunction<
      Int32 Function(IntPtr, Uint32, Pointer<IntPtr>),
      int Function(int, int, Pointer<IntPtr>)
    >('OpenProcessToken');

final getTokenInformation = _advapi32
    .lookupFunction<
      Int32 Function(IntPtr, Int32, Pointer<Void>, Uint32, Pointer<Uint32>),
      int Function(int, int, Pointer<Void>, int, Pointer<Uint32>)
    >('GetTokenInformation');

final convertSidToStringSid = _advapi32
    .lookupFunction<
      Int32 Function(Pointer<Void>, Pointer<Pointer<Utf16>>),
      int Function(Pointer<Void>, Pointer<Pointer<Utf16>>)
    >('ConvertSidToStringSidW');

final convertStringSecurityDescriptorToSecurityDescriptor = _advapi32
    .lookupFunction<
      Int32 Function(
        Pointer<Utf16>,
        Uint32,
        Pointer<Pointer<Void>>,
        Pointer<Uint32>,
      ),
      int Function(Pointer<Utf16>, int, Pointer<Pointer<Void>>, Pointer<Uint32>)
    >('ConvertStringSecurityDescriptorToSecurityDescriptorW');

/// SID (formato `S-1-5-...`) del usuario dueño del proceso [processHandle],
/// o `null` si no se pudo leer. No cierra [processHandle].
String? sidOfProcessHandle(int processHandle) {
  return using((arena) {
    final token = arena<IntPtr>();
    if (openProcessToken(processHandle, tokenQuery, token) == 0) return null;
    try {
      final needed = arena<Uint32>();
      getTokenInformation(token.value, tokenUserClass, nullptr, 0, needed);
      if (needed.value == 0) return null;
      final buffer = arena<Uint8>(needed.value);
      if (getTokenInformation(
            token.value,
            tokenUserClass,
            buffer.cast(),
            needed.value,
            needed,
          ) ==
          0) {
        return null;
      }
      // TOKEN_USER { SID_AND_ATTRIBUTES User { PSID Sid; DWORD Attributes } }
      final sid = buffer.cast<Pointer<Void>>().value;
      final sidString = arena<Pointer<Utf16>>();
      if (convertSidToStringSid(sid, sidString) == 0) return null;
      final result = sidString.value.toDartString();
      localFree(sidString.value.cast());
      return result;
    } finally {
      closeHandle(token.value);
    }
  });
}

/// SID del usuario del proceso actual.
String currentUserSid() {
  final sid = sidOfProcessHandle(getCurrentProcess());
  if (sid == null) {
    throw StateError('No se pudo leer el SID del usuario actual');
  }
  return sid;
}

/// SID del usuario dueño del proceso [pid], o `null` si no se pudo leer
/// (proceso de otro usuario sin permisos de consulta, proceso terminado).
String? sidOfPid(int pid) {
  final process = openProcess(processQueryLimitedInformation, 0, pid);
  if (process == 0) return null;
  try {
    return sidOfProcessHandle(process);
  } finally {
    closeHandle(process);
  }
}
