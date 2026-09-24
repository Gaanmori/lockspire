// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Lockspire

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:lockspire_bridge/lockspire_bridge.dart';
import 'package:lockspire_native_host/native_host.dart';
import 'package:test/test.dart';

class _FakeApp implements AppLink {
  final forwarded = <BridgeRequest>[];
  bool running = true;
  bool closed = false;

  @override
  Future<Map<String, Object?>> send(BridgeRequest request) async {
    if (!running) throw AppNotRunningException();
    forwarded.add(request);
    return pongResponse(request.id, locked: false);
  }

  @override
  Future<void> close() async => closed = true;
}

Future<List<Map<String, Object?>>> _run(
  List<List<int>> chunks,
  _FakeApp app,
) async {
  final out = FrameDecoder();
  final responses = <Map<String, Object?>>[];
  await runNativeHost(
    input: Stream.fromIterable(chunks),
    output: (frame) => responses.addAll(out.add(frame).map(decodeFrameBody)),
    app: app,
  );
  return responses;
}

void main() {
  test(
    'reenvía peticiones válidas y devuelve la respuesta de la app',
    () async {
      final app = _FakeApp();
      final responses = await _run([
        encodeFrame({'v': 1, 'id': 'a', 'type': 'PING'}),
      ], app);
      expect(responses, [pongResponse('a', locked: false)]);
      expect(app.forwarded.single, isA<PingRequest>());
      expect(app.closed, isTrue);
    },
  );

  test('peticiones inválidas nunca llegan a la app', () async {
    final app = _FakeApp();
    final responses = await _run([
      encodeFrame({'v': 1, 'id': 'a', 'type': 'PING', 'extra': 1}),
      encodeFrame({'v': 1, 'id': 'b', 'type': 'SAVE_CREDENTIAL'}),
      encodeFrame({
        'v': 1,
        'id': 'c',
        'type': 'GET_CREDENTIALS_FOR_ORIGIN',
        'origin': 'file:///etc/passwd',
      }),
    ], app);
    expect(responses, [
      errorResponse('a', ErrorCode.badRequest),
      errorResponse('b', ErrorCode.badRequest),
      errorResponse('c', ErrorCode.badRequest),
    ]);
    expect(app.forwarded, isEmpty);
  });

  test('sin app → APP_NOT_RUNNING con el id de la petición', () async {
    final app = _FakeApp()..running = false;
    final responses = await _run([
      encodeFrame({'v': 1, 'id': 'a', 'type': 'PING'}),
    ], app);
    expect(responses, [errorResponse('a', ErrorCode.appNotRunning)]);
  });

  test('frames partidos entre varios chunks de stdin', () async {
    final app = _FakeApp();
    final frame = encodeFrame({'v': 1, 'id': 'a', 'type': 'PING'});
    final responses = await _run([
      frame.sublist(0, 2),
      frame.sublist(2, 7),
      frame.sublist(7),
    ], app);
    expect(responses, [pongResponse('a', locked: false)]);
  });

  test('prefijo de longitud gigante → error y fin, sin leer más', () async {
    final app = _FakeApp();
    final header = Uint8List(4);
    ByteData.sublistView(header).setUint32(0, 0x7fffffff, Endian.little);
    final responses = await _run([header, utf8.encode('x' * 10)], app);
    expect(responses, [errorResponse(null, ErrorCode.badRequest)]);
    expect(app.forwarded, isEmpty);
  });

  test('callerFromArgs toma el origen de la extensión e ignora el resto', () {
    expect(
      callerFromArgs([
        'chrome-extension://abcdefghijklmnopabcdefghijklmnop/',
        '--parent-window=0',
      ]),
      'chrome-extension://abcdefghijklmnopabcdefghijklmnop/',
    );
    expect(callerFromArgs(['--parent-window=0']), isNull);
  });
}
