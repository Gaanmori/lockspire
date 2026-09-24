// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Lockspire

import 'dart:async';

import 'package:lockspire_bridge/lockspire_bridge.dart';

/// Enlace con la app. Abstraído para poder testear el relay sin IPC real.
abstract interface class AppLink {
  /// Reenvía [request] a la app y devuelve su respuesta. Lanza
  /// [AppNotRunningException] si la app no está en ejecución.
  Future<Map<String, Object?>> send(BridgeRequest request);

  Future<void> close();
}

/// [AppLink] real: conecta con la app por el canal IPC la primera vez que
/// hace falta y reutiliza la conexión.
class IpcAppLink implements AppLink {
  final IpcLocation _location;
  final String _caller;
  BridgeClient? _client;

  IpcAppLink({required this._location, required this._caller});

  @override
  Future<Map<String, Object?>> send(BridgeRequest request) async {
    final client = _client ??= await BridgeClient.connect(
      location: _location,
      client: ClientKind.nativeHost,
      caller: _caller,
    );
    try {
      return await client.request(request);
    } catch (_) {
      // Conexión rota (p. ej. la app se cerró): la siguiente petición
      // vuelve a conectar desde cero.
      _client = null;
      await client.close();
      rethrow;
    }
  }

  @override
  Future<void> close() async => _client?.close();
}

/// Bucle principal del native host (ADR 0005/0013): lee frames de Native
/// Messaging de [input] (stdin), los valida estrictamente, los reenvía a
/// la app y escribe la respuesta en [output] (stdout). Las peticiones se
/// atienden en serie.
///
/// Nunca escribe en [output] nada que no sea un frame del protocolo: el
/// navegador cerraría la conexión.
Future<void> runNativeHost({
  required Stream<List<int>> input,
  required void Function(List<int> frame) output,
  required AppLink app,
  void Function(String message) log = _noLog,
}) async {
  final decoder = FrameDecoder();
  try {
    await for (final chunk in input) {
      final List<List<int>> frames;
      try {
        frames = decoder.add(chunk);
      } on BridgeProtocolException {
        // Prefijo corrupto o frame gigante: el stream ya no es fiable.
        output(encodeFrame(errorResponse(null, ErrorCode.badRequest)));
        return;
      }
      for (final frame in frames) {
        output(encodeFrame(await _handleFrame(frame, app, log)));
      }
    }
  } finally {
    await app.close();
  }
}

void _noLog(String message) {}

Future<Map<String, Object?>> _handleFrame(
  List<int> body,
  AppLink app,
  void Function(String) log,
) async {
  final Map<String, Object?> json;
  try {
    json = decodeFrameBody(body);
  } on BridgeProtocolException {
    return errorResponse(null, ErrorCode.badRequest);
  }

  final BridgeRequest request;
  try {
    request = BridgeRequest.parse(json);
  } on BridgeProtocolException {
    return errorResponse(
      BridgeRequest.tryExtractId(json),
      ErrorCode.badRequest,
    );
  }

  try {
    return await app.send(request);
  } on AppNotRunningException catch (e) {
    log('${request.type}: $e');
    return errorResponse(request.id, ErrorCode.appNotRunning);
  } catch (e) {
    // Canal rechazado, respuesta inválida, timeout... Sin detalles hacia
    // la extensión; solo al log local.
    log('${request.type}: ${e.runtimeType}: $e');
    return errorResponse(request.id, ErrorCode.internal);
  }
}

/// El navegador pasa el origen de la extensión que lanzó al host como
/// argumento (`chrome-extension://<id>/`; en Windows también añade
/// `--parent-window=...`).
String? callerFromArgs(List<String> args) =>
    args.where((a) => a.startsWith('chrome-extension://')).firstOrNull;
