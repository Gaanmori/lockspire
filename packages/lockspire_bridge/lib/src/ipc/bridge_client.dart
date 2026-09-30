// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Gabriel Ángel Montoya Rico

import 'dart:io';

import '../protocol/messages.dart';
import 'ipc_location.dart';
import 'session_token.dart';
import 'unix_socket_transport.dart';
import 'windows_pipe_transport.dart';

/// No hay ninguna instancia de la app escuchando (o no se pudo llegar a
/// ella). [reason] es un diagnóstico técnico sin datos sensibles.
class AppNotRunningException implements Exception {
  final String? reason;

  AppNotRunningException([this.reason]);

  @override
  String toString() =>
      'Lockspire no está en ejecución${reason == null ? '' : ' ($reason)'}';
}

/// El proceso al otro lado del canal no corre como el mismo usuario del
/// SO, o rechazó el handshake. Nunca se le envía el token.
class BridgePeerRejectedException implements Exception {
  const BridgePeerRejectedException();
  @override
  String toString() => 'El otro extremo del canal IPC no es de confianza';
}

class BridgeConnectionClosedException implements Exception {
  const BridgeConnectionClosedException();
  @override
  String toString() => 'La conexión IPC se cerró';
}

/// Transporte de un cliente: envía un frame y espera el siguiente.
abstract interface class BridgeConnection {
  Future<Map<String, Object?>> exchange(
    Map<String, Object?> message, {
    Duration timeout,
  });

  Future<void> close();
}

/// Cliente del canal IPC de la app: lo usan el native host y una segunda
/// instancia de la app (ADR 0012/0013).
class BridgeClient {
  final BridgeConnection _connection;

  BridgeClient._(this._connection);

  /// Conecta, verifica que el servidor es del mismo usuario, lee el token
  /// y hace el `HELLO`. Lanza [AppNotRunningException] si no hay app, o
  /// [BridgePeerRejectedException] si el servidor no es de confianza o
  /// rechazó el handshake.
  static Future<BridgeClient> connect({
    required IpcLocation location,
    required ClientKind client,
    String? caller,
  }) async {
    final connection = Platform.isWindows
        ? await WindowsPipeConnection.connect(location)
        : await UnixSocketConnection.connect(location);
    try {
      final String token;
      try {
        token = readSessionToken(location.tokenPath);
      } on FileSystemException catch (e) {
        // La ruta y qué hay en la carpeta (nombres, nunca el contenido):
        // para distinguir "la app no escribió el token" de "este proceso
        // ve otra carpeta" (2026-09-30).
        final dir = Directory(location.directory);
        final seen = dir.existsSync()
            ? dir.listSync().map((f) => f.uri.pathSegments.last).join(', ')
            : '(la carpeta no existe)';
        throw AppNotRunningException(
          'no se pudo leer el token en ${location.tokenPath}: '
          '${e.osError?.message ?? e.message}; en la carpeta: $seen',
        );
      }
      final reply = await connection.exchange(
        HelloMessage(token: token, client: client, caller: caller).toJson(),
        timeout: const Duration(seconds: 5),
      );
      expectHelloOk(reply);
      return BridgeClient._(connection);
    } on BridgeConnectionClosedException {
      await connection.close();
      throw const BridgePeerRejectedException();
    } catch (_) {
      await connection.close();
      rethrow;
    }
  }

  /// Envía una petición y devuelve la respuesta, comprobando que
  /// correlaciona con ella.
  Future<Map<String, Object?>> request(BridgeRequest request) async {
    final response = await _connection.exchange(request.toJson());
    expectResponseEnvelope(response, requestId: request.id);
    return response;
  }

  Future<void> close() => _connection.close();
}
