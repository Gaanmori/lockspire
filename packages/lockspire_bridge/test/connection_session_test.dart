// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Gabriel Ángel Montoya Rico

import 'dart:convert';
import 'dart:typed_data';

import 'package:lockspire_bridge/lockspire_bridge.dart';
import 'package:test/test.dart';

const _token = 'BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB';
const _caller = 'chrome-extension://abcdefghijklmnopabcdefghijklmnop/';

Uint8List _body(Map<String, Object?> json) => utf8.encode(jsonEncode(json));

Map<String, Object?> _hello({
  String token = _token,
  String client = 'native-host',
}) => {
  'v': 1,
  'type': 'HELLO',
  'token': token,
  'client': client,
  if (client == 'native-host') 'caller': _caller,
};

void main() {
  late List<BridgeRequest> handled;
  late ConnectionSession session;

  setUp(() {
    handled = [];
    session = ConnectionSession(
      expectedToken: _token,
      handler: (request, client) async {
        handled.add(request);
        return okResponse(request.id);
      },
    );
  });

  test(
    'sin HELLO, cualquier otra cosa cierra la conexión sin responder',
    () async {
      final reply = await session.onFrame(
        _body({'v': 1, 'id': 'x', 'type': 'PING'}),
      );
      expect(reply.response, isNull);
      expect(reply.close, isTrue);
      expect(handled, isEmpty);
    },
  );

  test('token incorrecto cierra sin responder', () async {
    final reply = await session.onFrame(
      _body(_hello(token: 'CCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCC')),
    );
    expect(reply.response, isNull);
    expect(reply.close, isTrue);
    expect(session.isAuthenticated, isFalse);
  });

  test('JSON basura antes del HELLO cierra sin responder', () async {
    final reply = await session.onFrame(utf8.encode('{basura'));
    expect(reply.close, isTrue);
  });

  test('HELLO correcto → HELLO_OK, y después atiende peticiones', () async {
    final hello = await session.onFrame(_body(_hello()));
    expect(hello.response?['type'], 'HELLO_OK');
    expect(hello.close, isFalse);

    final reply = await session.onFrame(
      _body({'v': 1, 'id': 'p1', 'type': 'PING'}),
    );
    expect(reply.response, okResponse('p1'));
    expect(handled.single, isA<PingRequest>());
  });

  test('petición inválida tras el HELLO → ERROR BAD_REQUEST, sin cerrar ni '
      'llamar al handler', () async {
    await session.onFrame(_body(_hello()));
    final reply = await session.onFrame(
      _body({'v': 1, 'id': 'p1', 'type': 'PING', 'extra': true}),
    );
    expect(reply.response, errorResponse('p1', ErrorCode.badRequest));
    expect(reply.close, isFalse);
    expect(handled, isEmpty);
  });

  test(
    'una segunda instancia de la app solo puede pedir SHOW_APP/PING',
    () async {
      await session.onFrame(_body(_hello(client: 'app-instance')));
      final denied = await session.onFrame(
        _body({
          'v': 1,
          'id': 'c1',
          'type': 'GET_CREDENTIALS_FOR_ORIGIN',
          'origin': 'https://example.com',
        }),
      );
      expect(denied.response, errorResponse('c1', ErrorCode.badRequest));
      expect(handled, isEmpty);

      final allowed = await session.onFrame(
        _body({'v': 1, 'id': 's1', 'type': 'SHOW_APP'}),
      );
      expect(allowed.response, okResponse('s1'));
    },
  );

  test(
    'si el handler lanza, responde ERROR INTERNAL sin filtrar detalles',
    () async {
      final failing = ConnectionSession(
        expectedToken: _token,
        handler: (request, client) async => throw StateError('secreto interno'),
      );
      await failing.onFrame(_body(_hello()));
      final reply = await failing.onFrame(
        _body({'v': 1, 'id': 'p1', 'type': 'PING'}),
      );
      expect(reply.response, errorResponse('p1', ErrorCode.internal));
      expect(jsonEncode(reply.response), isNot(contains('secreto')));
    },
  );
}
