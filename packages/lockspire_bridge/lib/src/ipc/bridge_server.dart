// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Gabriel Ángel Montoya Rico

import 'dart:io';

import 'connection_session.dart';
import 'ipc_location.dart';
import 'unix_socket_transport.dart';
import 'windows_pipe_transport.dart';

/// Ya hay otra instancia de la app escuchando en el mismo endpoint.
class BridgeServerAlreadyRunningException implements Exception {
  @override
  String toString() => 'Ya hay una instancia de Lockspire escuchando';
}

/// Servidor IPC de la app (ADR 0013). Genera un token nuevo, lo escribe
/// con permisos restringidos y atiende conexiones: `HELLO` con token, y
/// después peticiones validadas que delega en el handler.
abstract interface class BridgeServer {
  /// Lanza [BridgeServerAlreadyRunningException] si otra instancia ya
  /// tiene el endpoint.
  static Future<BridgeServer> start({
    required IpcLocation location,
    required BridgeRequestHandler handler,
    Duration helloTimeout = const Duration(seconds: 5),
  }) {
    if (Platform.isWindows) {
      return WindowsPipeServer.start(
        location: location,
        handler: handler,
        helloTimeout: helloTimeout,
      );
    }
    return UnixSocketServer.start(
      location: location,
      handler: handler,
      helloTimeout: helloTimeout,
    );
  }

  Future<void> close();
}
