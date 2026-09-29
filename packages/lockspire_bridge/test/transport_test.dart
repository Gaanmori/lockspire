// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Gabriel Ángel Montoya Rico

// Transporte IPC real contra el sistema operativo (named pipe en Windows,
// socket Unix en Linux) — sin mocks, ver ADR 0013.
//
// El cliente de Windows hace llamadas bloqueantes (ReadFile) en el isolate
// que lo usa. En producción el cliente es otro proceso (native host) o un
// isolate aparte (segunda instancia de la app); aquí el servidor vive en el
// isolate del test, así que cada interacción de cliente corre en otro
// isolate (ver [_isolated]) — si no, cliente y servidor se bloquean
// mutuamente.

@TestOn('windows || linux')
library;

import 'dart:io';
import 'dart:isolate';
import 'dart:math';

import 'package:lockspire_bridge/lockspire_bridge.dart';
import 'package:lockspire_bridge/src/ipc/posix_ffi.dart' as posix;
import 'package:lockspire_bridge/src/ipc/unix_socket_transport.dart';
import 'package:lockspire_bridge/src/ipc/windows_pipe_transport.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

const _caller = 'chrome-extension://abcdefghijklmnopabcdefghijklmnop/';

IpcLocation _tempLocation(Directory root) {
  final suffix = Random.secure().nextInt(1 << 32).toRadixString(16);
  final dir = p.join(root.path, 'lockspire');
  return IpcLocation(
    endpoint: Platform.isWindows
        ? r'\\.\pipe\lockspire-test-' + suffix
        : p.join(dir, 'ipc.sock'),
    tokenPath: p.join(dir, 'ipc.token'),
    directory: dir,
  );
}

/// Ejecuta [body] en otro isolate. La closure se crea aquí (y no dentro
/// del test) para que solo capture [location] y [body] — las closures de
/// los tests capturan también el servidor, que no se puede enviar.
Future<T> _isolated<T>(
  IpcLocation location,
  Future<T> Function(IpcLocation) body,
) => Isolate.run(() => body(location));

Future<BridgeConnection> _rawConnect(IpcLocation location) async =>
    Platform.isWindows
    ? await WindowsPipeConnection.connect(location)
    : await UnixSocketConnection.connect(location);

Future<BridgeClient> _connectHost(IpcLocation location) => BridgeClient.connect(
  location: location,
  client: ClientKind.nativeHost,
  caller: _caller,
);

Future<List<Map<String, Object?>>> _pingAndShow(IpcLocation location) async {
  final client = await _connectHost(location);
  final ping = await client.request(const PingRequest('a'));
  final show = await client.request(const ShowAppRequest('b'));
  await client.close();
  return [ping, show];
}

Future<String> _connectAndReportError(IpcLocation location) async {
  try {
    final client = await _connectHost(location);
    await client.close();
    return 'ok';
  } catch (e) {
    return e.runtimeType.toString();
  }
}

Future<bool> _silentThenExchangeFails(IpcLocation location) async {
  final raw = await _rawConnect(location);
  await Future<void>.delayed(const Duration(milliseconds: 1000));
  try {
    await raw.exchange({'v': 1, 'id': 'x', 'type': 'PING'});
    return false;
  } catch (_) {
    return true;
  } finally {
    await raw.close();
  }
}

Future<String?> _pingWithoutHello(IpcLocation location) async {
  final raw = await _rawConnect(location);
  try {
    await raw.exchange({'v': 1, 'id': 'x', 'type': 'PING'});
    return null;
  } catch (e) {
    return e.runtimeType.toString();
  } finally {
    await raw.close();
  }
}

Future<Object?> _appInstancePing(IpcLocation location) async {
  final client = await BridgeClient.connect(
    location: location,
    client: ClientKind.appInstance,
  );
  final response = await client.request(const PingRequest('p'));
  await client.close();
  return response['type'];
}

void main() {
  late Directory root;
  late IpcLocation location;
  BridgeServer? server;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('lockspire_bridge_');
    // ensureDirectory exige que el padre sea 0700, como lo es
    // $XDG_RUNTIME_DIR. createTemp no lo garantiza: respeta el umask (en
    // los runners de GitHub queda 0755), así que se fija explícitamente.
    if (Platform.isLinux) posix.chmod(root.path, 0x1C0);
    location = _tempLocation(root);
  });

  tearDown(() async {
    await server?.close();
    server = null;
    await root.delete(recursive: true);
  });

  Future<BridgeServer> startServer({
    Duration helloTimeout = const Duration(seconds: 5),
  }) async {
    return server = await BridgeServer.start(
      location: location,
      helloTimeout: helloTimeout,
      handler: (request, client) async => switch (request) {
        PingRequest() => pongResponse(request.id, locked: true),
        _ => okResponse(request.id),
      },
    );
  }

  test('sin app escuchando → AppNotRunningException', () async {
    location.ensureDirectory();
    expect(
      await _isolated(location, _connectAndReportError),
      'AppNotRunningException',
    );
  });

  test('HELLO con el token del archivo y varias peticiones en la misma '
      'conexión', () async {
    await startServer();
    final responses = await _isolated(location, _pingAndShow);
    expect(responses[0], {'v': 1, 'id': 'a', 'type': 'PONG', 'locked': true});
    expect(responses[1]['type'], MessageType.ok);
  });

  test(
    'token incorrecto → el servidor cierra y el cliente lo rechaza',
    () async {
      await startServer();
      final wrongTokenPath = p.join(location.directory, 'otro.token');
      File(wrongTokenPath).writeAsStringSync('D' * 43);
      final wrong = IpcLocation(
        endpoint: location.endpoint,
        tokenPath: wrongTokenPath,
        directory: location.directory,
      );
      expect(
        await _isolated(wrong, _connectAndReportError),
        'BridgePeerRejectedException',
      );
    },
  );

  test('una segunda instancia en el mismo endpoint → AlreadyRunning, sin '
      'pisar el token de la primera', () async {
    await startServer();
    final token = File(location.tokenPath).readAsStringSync();
    await expectLater(
      BridgeServer.start(
        location: location,
        handler: (request, client) async => okResponse(request.id),
      ),
      throwsA(isA<BridgeServerAlreadyRunningException>()),
    );
    expect(File(location.tokenPath).readAsStringSync(), token);
  });

  test('una conexión que no manda HELLO se cierra tras el timeout', () async {
    await startServer(helloTimeout: const Duration(milliseconds: 300));
    expect(await _isolated(location, _silentThenExchangeFails), isTrue);
  });

  test(
    'frame que no es HELLO como primer mensaje → cierre sin respuesta',
    () async {
      await startServer();
      expect(
        await _isolated(location, _pingWithoutHello),
        'BridgeConnectionClosedException',
      );
    },
  );

  test(
    'el servidor sigue aceptando conexiones nuevas tras cerrar otras',
    () async {
      await startServer();
      for (var i = 0; i < 3; i++) {
        expect(await _isolated(location, _appInstancePing), MessageType.pong);
      }
    },
  );

  test(
    'Linux: un socket huérfano de una ejecución anterior no impide arrancar',
    () async {
      location.ensureDirectory();
      // Un servidor que se cierra sin borrar su archivo deja el socket en
      // disco sin nadie escuchando: lo mismo que un proceso que murió.
      final stale = await ServerSocket.bind(
        InternetAddress(location.endpoint, type: InternetAddressType.unix),
        0,
      );
      await stale.close();
      await startServer();
      expect(await _isolated(location, _appInstancePing), MessageType.pong);
    },
    testOn: 'linux',
  );

  test('Linux: directorio 0700 y token 0600', () async {
    await startServer();
    expect(FileStat.statSync(location.directory).mode & 0x1FF, 0x1C0);
    expect(FileStat.statSync(location.tokenPath).mode & 0x1FF, 0x180);
  }, testOn: 'linux');
}
