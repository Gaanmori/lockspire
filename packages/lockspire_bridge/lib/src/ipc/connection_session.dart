// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Lockspire

import 'dart:typed_data';

import '../protocol/framing.dart';
import '../protocol/messages.dart';
import '../protocol/protocol_exception.dart';
import 'session_token.dart';

/// Atiende una petición ya validada y devuelve la respuesta (el objeto
/// JSON completo, con `v`/`id`/`type`).
typedef BridgeRequestHandler =
    Future<Map<String, Object?>> Function(
      BridgeRequest request,
      ClientKind client,
    );

/// Qué hacer tras procesar un frame.
class SessionReply {
  /// Respuesta a enviar, o `null` si no hay que enviar nada.
  final Map<String, Object?>? response;

  /// Cerrar la conexión después de (eventualmente) enviar [response].
  final bool close;

  const SessionReply(this.response, {this.close = false});
}

/// Máquina de estados de una conexión IPC en el lado de la app,
/// independiente del transporte: primero exige un `HELLO` con el token
/// correcto; después, cada frame es una petición validada estrictamente.
///
/// Un `HELLO` inválido o con token incorrecto cierra la conexión sin
/// responder (no se le da al otro lado información para iterar).
class ConnectionSession {
  final String _expectedToken;
  final BridgeRequestHandler _handler;
  ClientKind? _client;

  ConnectionSession({
    required this._expectedToken,
    required this._handler,
  });

  bool get isAuthenticated => _client != null;

  Future<SessionReply> onFrame(Uint8List body) async {
    final Map<String, Object?> json;
    try {
      json = decodeFrameBody(body);
    } on BridgeProtocolException {
      return isAuthenticated
          ? SessionReply(errorResponse(null, ErrorCode.badRequest))
          : const SessionReply(null, close: true);
    }

    final client = _client;
    if (client == null) return _onHello(json);

    final BridgeRequest request;
    try {
      request = BridgeRequest.parse(json);
    } on BridgeProtocolException {
      return SessionReply(
        errorResponse(BridgeRequest.tryExtractId(json), ErrorCode.badRequest),
      );
    }

    // Una segunda instancia de la app solo puede pedir que se muestre la
    // primera (ADR 0012) — nunca credenciales.
    if (client == ClientKind.appInstance &&
        request is! ShowAppRequest &&
        request is! PingRequest) {
      return SessionReply(errorResponse(request.id, ErrorCode.badRequest));
    }

    try {
      return SessionReply(await _handler(request, client));
    } catch (_) {
      return SessionReply(errorResponse(request.id, ErrorCode.internal));
    }
  }

  SessionReply _onHello(Map<String, Object?> json) {
    try {
      final hello = HelloMessage.parse(json);
      if (!tokensEqual(hello.token, _expectedToken)) {
        return const SessionReply(null, close: true);
      }
      _client = hello.client;
      return SessionReply(helloOk());
    } on BridgeProtocolException {
      return const SessionReply(null, close: true);
    }
  }
}
