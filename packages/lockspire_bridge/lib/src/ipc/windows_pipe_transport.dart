// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Lockspire

import 'dart:async';
import 'dart:ffi';
import 'dart:io' show sleep;
import 'dart:isolate';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';

import '../protocol/framing.dart';
import 'bridge_client.dart';
import 'bridge_server.dart';
import 'connection_session.dart';
import 'ipc_location.dart';
import 'session_token.dart';
import 'win32_ffi.dart';

const _pipeBufferSize = 64 * 1024;

/// [BridgeServer] sobre named pipe (Windows).
///
/// `dart:io` no soporta named pipes (ADR 0013): se usa Win32 vía FFI. Las
/// llamadas bloquean, así que viven en isolates propios:
///
/// - un isolate *acceptor* crea instancias del pipe y espera clientes
///   (`ConnectNamedPipe`);
/// - un isolate por conexión lee frames (`ReadFile`) y escribe respuestas.
///
/// El isolate principal es el **único dueño de los handles**: verifica el
/// usuario del cliente, aplica el timeout del `HELLO` (con
/// `DisconnectNamedPipe`, que desbloquea el `ReadFile` pendiente) y cierra
/// cada handle una sola vez. Así no hay carreras de cierre doble ni de
/// reutilización de handles entre isolates.
class WindowsPipeServer implements BridgeServer {
  final Isolate _acceptor;
  final ReceivePort _acceptPort;
  final Pointer<Int32> _stopFlag;
  final String _endpoint;
  final _connections = <int, _PipeConnection>{};

  WindowsPipeServer._(
    this._acceptor,
    this._acceptPort,
    this._stopFlag,
    this._endpoint,
  );

  static Future<WindowsPipeServer> start({
    required IpcLocation location,
    required BridgeRequestHandler handler,
    required Duration helloTimeout,
  }) async {
    location.ensureDirectory();
    final ownSid = currentUserSid();
    final sddl = 'D:P(A;;GA;;;$ownSid)';

    // La primera instancia se crea aquí (no en el isolate) para detectar
    // de inmediato si el nombre ya está tomado.
    final first = _createPipeInstance(location.endpoint, sddl, first: true);
    if (first == invalidHandleValue) {
      throw BridgeServerAlreadyRunningException();
    }

    // Token después de reclamar el nombre: si ya había otra instancia no
    // se pisa su token.
    final token = generateSessionToken();
    writeSessionToken(location.tokenPath, token);

    final stopFlag = calloc<Int32>();
    final acceptPort = ReceivePort();
    final acceptor = await Isolate.spawn(
      _acceptLoop,
      _AcceptArgs(
        firstHandle: first,
        endpoint: location.endpoint,
        sddl: sddl,
        stopFlagAddress: stopFlag.address,
        port: acceptPort.sendPort,
      ),
      debugName: 'lockspire-ipc-acceptor',
    );

    final server = WindowsPipeServer._(
      acceptor,
      acceptPort,
      stopFlag,
      location.endpoint,
    );
    acceptPort.listen((message) {
      if (message is int) {
        server._onClientConnected(
          message,
          ownSid,
          token,
          handler,
          helloTimeout,
        );
      }
    });
    return server;
  }

  void _onClientConnected(
    int handle,
    String ownSid,
    String token,
    BridgeRequestHandler handler,
    Duration helloTimeout,
  ) {
    if (_stopFlag.value != 0) {
      _release(handle);
      return;
    }
    final clientSid = using((arena) {
      final pid = arena<Uint32>();
      if (getNamedPipeClientProcessId(handle, pid) == 0) return null;
      return sidOfPid(pid.value);
    });
    if (clientSid != ownSid) {
      _release(handle);
      return;
    }
    final connection = _PipeConnection(
      handle: handle,
      session: ConnectionSession(expectedToken: token, handler: handler),
      onDone: () {
        _connections.remove(handle);
        _release(handle);
      },
    );
    _connections[handle] = connection;
    connection.start(helloTimeout);
  }

  static void _release(int handle) {
    disconnectNamedPipe(handle);
    closeHandle(handle);
  }

  @override
  Future<void> close() async {
    _stopFlag.value = 1;
    // Despertar al acceptor, bloqueado en ConnectNamedPipe: conectarse
    // una vez hace que vea el flag y termine.
    try {
      final wake = using((arena) {
        return createFile(
          _endpoint.toNativeUtf16(allocator: arena),
          genericRead | genericWrite,
          0,
          nullptr,
          openExisting,
          0,
          0,
        );
      });
      if (wake != invalidHandleValue) closeHandle(wake);
    } catch (_) {}
    for (final connection in _connections.values.toList()) {
      connection.abort();
    }
    _acceptPort.close();
    _acceptor.kill(priority: Isolate.beforeNextEvent);
  }
}

/// Estado de una conexión en el isolate principal.
class _PipeConnection {
  final int handle;
  final ConnectionSession session;
  final void Function() onDone;
  final _fromIsolate = ReceivePort();
  SendPort? _toIsolate;
  Timer? _helloTimer;
  bool _done = false;

  _PipeConnection({
    required this.handle,
    required this.session,
    required this.onDone,
  });

  void start(Duration helloTimeout) {
    _helloTimer = Timer(helloTimeout, () {
      if (!session.isAuthenticated) abort();
    });
    _fromIsolate.listen(_onMessage);
    unawaited(
      Isolate.spawn(
        _connectionLoop,
        _ConnectionArgs(handle: handle, port: _fromIsolate.sendPort),
        debugName: 'lockspire-ipc-connection',
      ),
    );
  }

  Future<void> _onMessage(Object? message) async {
    if (message is SendPort) {
      _toIsolate = message;
    } else if (message is TransferableTypedData) {
      final reply = await session.onFrame(message.materialize().asUint8List());
      final response = reply.response;
      _toIsolate?.send(
        _Reply(
          frame: response == null
              ? null
              : TransferableTypedData.fromList([encodeFrame(response)]),
          close: reply.close,
        ),
      );
    } else if (message == _doneMessage) {
      _finish();
    }
  }

  /// Corta la conexión desde el isolate principal: `DisconnectNamedPipe`
  /// hace fallar el `ReadFile` bloqueado del isolate de la conexión, que
  /// entonces avisa con `_doneMessage` y [_finish] libera el handle.
  void abort() {
    if (_done) return;
    disconnectNamedPipe(handle);
  }

  void _finish() {
    if (_done) return;
    _done = true;
    _helloTimer?.cancel();
    _fromIsolate.close();
    onDone();
  }
}

const _doneMessage = 'done';

class _AcceptArgs {
  final int firstHandle;
  final String endpoint;
  final String sddl;
  final int stopFlagAddress;
  final SendPort port;

  _AcceptArgs({
    required this.firstHandle,
    required this.endpoint,
    required this.sddl,
    required this.stopFlagAddress,
    required this.port,
  });
}

class _ConnectionArgs {
  final int handle;
  final SendPort port;

  _ConnectionArgs({required this.handle, required this.port});
}

class _Reply {
  final TransferableTypedData? frame;
  final bool close;

  _Reply({required this.frame, required this.close});
}

int _createPipeInstance(String endpoint, String sddl, {required bool first}) {
  return using((arena) {
    final descriptor = arena<Pointer<Void>>();
    if (convertStringSecurityDescriptorToSecurityDescriptor(
          sddl.toNativeUtf16(allocator: arena),
          sddlRevision1,
          descriptor,
          nullptr,
        ) ==
        0) {
      return invalidHandleValue;
    }
    try {
      final attributes = arena<SecurityAttributes>();
      attributes.ref
        ..nLength = sizeOf<SecurityAttributes>()
        ..lpSecurityDescriptor = descriptor.value
        ..bInheritHandle = 0;
      return createNamedPipe(
        endpoint.toNativeUtf16(allocator: arena),
        pipeAccessDuplex | (first ? fileFlagFirstPipeInstance : 0),
        pipeTypeByte | pipeReadmodeByte | pipeWait | pipeRejectRemoteClients,
        pipeUnlimitedInstances,
        _pipeBufferSize,
        _pipeBufferSize,
        0,
        attributes,
      );
    } finally {
      localFree(descriptor.value);
    }
  });
}

bool _hasClient(int handle) => using((arena) {
  // ConnectNamedPipe devuelve FALSE con ERROR_PIPE_CONNECTED si el cliente
  // conectó antes de la llamada. En vez de GetLastError (poco fiable desde
  // Dart FFI) se comprueba directamente si hay un cliente.
  return getNamedPipeClientProcessId(handle, arena<Uint32>()) != 0;
});

void _acceptLoop(_AcceptArgs args) {
  final stop = Pointer<Int32>.fromAddress(args.stopFlagAddress);
  var handle = args.firstHandle;
  while (true) {
    final connected =
        connectNamedPipe(handle, nullptr) != 0 || _hasClient(handle);
    if (stop.value != 0) {
      disconnectNamedPipe(handle);
      closeHandle(handle);
      return;
    }
    if (connected) {
      args.port.send(handle);
    } else {
      closeHandle(handle);
    }
    handle = _createPipeInstance(args.endpoint, args.sddl, first: false);
    while (handle == invalidHandleValue) {
      if (stop.value != 0) return;
      // Fallo transitorio de CreateNamedPipe: reintentar sin girar en vacío.
      sleep(const Duration(milliseconds: 200));
      handle = _createPipeInstance(args.endpoint, args.sddl, first: false);
    }
  }
}

Future<void> _connectionLoop(_ConnectionArgs args) async {
  final replies = ReceivePort();
  args.port.send(replies.sendPort);
  final iterator = StreamIterator<Object?>(replies);
  try {
    while (true) {
      final body = readFrameBlocking(args.handle);
      if (body == null) break;
      args.port.send(TransferableTypedData.fromList([body]));
      if (!await iterator.moveNext()) break;
      final reply = iterator.current as _Reply;
      final frame = reply.frame;
      if (frame != null &&
          !writeAllBlocking(args.handle, frame.materialize().asUint8List())) {
        break;
      }
      if (reply.close) break;
    }
  } finally {
    await iterator.cancel();
    args.port.send(_doneMessage);
  }
}

/// Lee exactamente [length] bytes. `null` si el pipe se cerró o falló.
Uint8List? _readExactBlocking(int handle, int length) {
  final result = Uint8List(length);
  if (length == 0) return result;
  return using((arena) {
    final buffer = arena<Uint8>(length);
    final read = arena<Uint32>();
    var offset = 0;
    while (offset < length) {
      final ok = readFile(
        handle,
        buffer + offset,
        length - offset,
        read,
        nullptr,
      );
      if (ok == 0 || read.value == 0) return null;
      offset += read.value;
    }
    result.setAll(0, buffer.asTypedList(length));
    return result;
  });
}

/// Lee un frame completo (prefijo + cuerpo) y devuelve el cuerpo. `null`
/// si el pipe se cerró, falló o el frame supera [maxFrameBytes].
Uint8List? readFrameBlocking(int handle) {
  final header = _readExactBlocking(handle, 4);
  if (header == null) return null;
  final length = ByteData.sublistView(header).getUint32(0, Endian.little);
  if (length > maxFrameBytes) return null;
  return _readExactBlocking(handle, length);
}

bool writeAllBlocking(int handle, Uint8List data) {
  return using((arena) {
    final buffer = arena<Uint8>(data.length);
    buffer.asTypedList(data.length).setAll(0, data);
    final written = arena<Uint32>();
    var offset = 0;
    while (offset < data.length) {
      final ok = writeFile(
        handle,
        buffer + offset,
        data.length - offset,
        written,
        nullptr,
      );
      if (ok == 0) return false;
      offset += written.value;
    }
    return true;
  });
}

/// [BridgeConnection] sobre named pipe (Windows). Usa llamadas bloqueantes
/// en el isolate que la crea: pensado para el native host (proceso de
/// línea de comandos, peticiones en serie) o para ejecutarse dentro de un
/// isolate aparte.
class WindowsPipeConnection implements BridgeConnection {
  final int _handle;
  bool _closed = false;

  WindowsPipeConnection._(this._handle);

  /// Conecta y verifica que el servidor corre como el mismo usuario antes
  /// de enviarle nada (anti pipe-squatting, ADR 0013).
  static Future<WindowsPipeConnection> connect(IpcLocation location) async {
    final handle = using((arena) {
      final name = location.endpoint.toNativeUtf16(allocator: arena);
      for (var attempt = 0; attempt < 3; attempt++) {
        // Falla de inmediato si el pipe no existe; espera si está ocupado.
        if (waitNamedPipe(name, 2000) == 0) return invalidHandleValue;
        final h = createFile(
          name,
          genericRead | genericWrite,
          0,
          nullptr,
          openExisting,
          securitySqosPresent | securityIdentification,
          0,
        );
        if (h != invalidHandleValue) return h;
      }
      return invalidHandleValue;
    });
    if (handle == invalidHandleValue) throw AppNotRunningException();

    final serverSid = using((arena) {
      final pid = arena<Uint32>();
      if (getNamedPipeServerProcessId(handle, pid) == 0) return null;
      return sidOfPid(pid.value);
    });
    if (serverSid == null || serverSid != currentUserSid()) {
      closeHandle(handle);
      throw const BridgePeerRejectedException();
    }
    return WindowsPipeConnection._(handle);
  }

  @override
  Future<Map<String, Object?>> exchange(
    Map<String, Object?> message, {
    Duration timeout = const Duration(seconds: 10),
  }) async {
    // El timeout no aplica: las llamadas son bloqueantes. El navegador
    // mata al host si la extensión cierra el puerto.
    if (_closed || !writeAllBlocking(_handle, encodeFrame(message))) {
      throw const BridgeConnectionClosedException();
    }
    final body = readFrameBlocking(_handle);
    if (body == null) throw const BridgeConnectionClosedException();
    return decodeFrameBody(body);
  }

  @override
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    closeHandle(_handle);
  }
}
