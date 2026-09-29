// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Gabriel Ángel Montoya Rico

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import '../protocol/framing.dart';
import 'bridge_client.dart';
import 'bridge_server.dart';
import 'connection_session.dart';
import 'ipc_location.dart';
import 'posix_ffi.dart' as posix;
import 'session_token.dart';

/// [BridgeServer] sobre socket Unix (Linux).
class UnixSocketServer implements BridgeServer {
  final ServerSocket _server;
  final IpcLocation _location;
  final _connections = <Socket>{};

  UnixSocketServer._(this._server, this._location);

  static Future<UnixSocketServer> start({
    required IpcLocation location,
    required BridgeRequestHandler handler,
    required Duration helloTimeout,
  }) async {
    location.ensureDirectory();
    final address = InternetAddress(
      location.endpoint,
      type: InternetAddressType.unix,
    );

    if (File(location.endpoint).existsSync() ||
        FileSystemEntity.typeSync(location.endpoint) ==
            FileSystemEntityType.unixDomainSock) {
      // ¿Hay alguien escuchando o es un socket huérfano de una ejecución
      // anterior que terminó mal?
      try {
        final probe = await Socket.connect(
          address,
          0,
          timeout: const Duration(seconds: 1),
        );
        probe.destroy();
        throw BridgeServerAlreadyRunningException();
      } on SocketException {
        File(location.endpoint).deleteSync();
      }
    }

    // El token se escribe antes de escuchar: un cliente nunca puede leer
    // el token de una ejecución anterior y conectar a la nueva.
    final token = generateSessionToken();
    writeSessionToken(location.tokenPath, token);

    final server = await ServerSocket.bind(address, 0);
    final instance = UnixSocketServer._(server, location);
    server.listen(
      (socket) => instance._accept(socket, token, handler, helloTimeout),
    );
    return instance;
  }

  void _accept(
    Socket socket,
    String token,
    BridgeRequestHandler handler,
    Duration helloTimeout,
  ) {
    try {
      if (posix.peerUid(socket) != posix.currentUid()) {
        socket.destroy();
        return;
      }
    } catch (_) {
      socket.destroy();
      return;
    }
    _connections.add(socket);

    final session = ConnectionSession(expectedToken: token, handler: handler);
    final decoder = FrameDecoder();
    final helloTimer = Timer(helloTimeout, () {
      if (!session.isAuthenticated) socket.destroy();
    });

    // Las peticiones de una conexión se atienden en orden: la siguiente
    // no empieza hasta que la anterior respondió.
    var queue = Future<void>.value();
    late final StreamSubscription<Uint8List> subscription;
    subscription = socket.listen(
      (chunk) {
        final List<Uint8List> frames;
        try {
          frames = decoder.add(chunk);
        } catch (_) {
          socket.destroy();
          return;
        }
        for (final frame in frames) {
          queue = queue.then((_) async {
            final reply = await session.onFrame(frame);
            final response = reply.response;
            if (response != null) socket.add(encodeFrame(response));
            if (reply.close) {
              await socket.flush();
              socket.destroy();
              await subscription.cancel();
            }
          });
        }
      },
      onError: (_) => socket.destroy(),
      onDone: () {
        helloTimer.cancel();
        _connections.remove(socket);
        socket.destroy();
      },
      cancelOnError: true,
    );
  }

  @override
  Future<void> close() async {
    await _server.close();
    for (final socket in _connections.toList()) {
      socket.destroy();
    }
    _connections.clear();
    try {
      File(_location.endpoint).deleteSync();
    } catch (_) {}
  }
}

/// [BridgeConnection] sobre socket Unix (Linux).
class UnixSocketConnection implements BridgeConnection {
  final Socket _socket;
  final _decoder = FrameDecoder();
  final _frames = StreamController<Uint8List>();
  late final StreamIterator<Uint8List> _iterator = StreamIterator(
    _frames.stream,
  );

  UnixSocketConnection._(this._socket) {
    _socket.listen(
      (chunk) {
        try {
          for (final frame in _decoder.add(chunk)) {
            _frames.add(frame);
          }
        } catch (e) {
          _frames.addError(e);
          _socket.destroy();
        }
      },
      onError: (Object e) => _frames.addError(e),
      onDone: () => _frames.close(),
    );
  }

  /// Conecta y verifica que el servidor corre como el mismo usuario antes
  /// de enviarle nada (ADR 0013).
  static Future<UnixSocketConnection> connect(IpcLocation location) async {
    final Socket socket;
    try {
      socket = await Socket.connect(
        InternetAddress(location.endpoint, type: InternetAddressType.unix),
        0,
        timeout: const Duration(seconds: 2),
      );
    } on SocketException {
      throw AppNotRunningException();
    }
    if (posix.peerUid(socket) != posix.currentUid()) {
      socket.destroy();
      throw const BridgePeerRejectedException();
    }
    return UnixSocketConnection._(socket);
  }

  @override
  Future<Map<String, Object?>> exchange(
    Map<String, Object?> message, {
    Duration timeout = const Duration(seconds: 10),
  }) async {
    _socket.add(encodeFrame(message));
    await _socket.flush();
    final hasNext = await _iterator.moveNext().timeout(timeout);
    if (!hasNext) throw const BridgeConnectionClosedException();
    return decodeFrameBody(_iterator.current);
  }

  @override
  Future<void> close() async {
    _socket.destroy();
    await _iterator.cancel();
  }
}
