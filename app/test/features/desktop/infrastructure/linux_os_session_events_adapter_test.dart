// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Gabriel Ángel Montoya Rico

// El servidor D-Bus de prueba lee con `RawSocket.readMessage`, que solo
// existe en Unix: en Windows no contesta. Corre en la CI de Linux.
@TestOn('linux')
library;

import 'dart:io' show pid;

import 'package:dbus/dbus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lockspire/features/desktop/infrastructure/linux_os_session_events_adapter.dart';

final _ownSession = DBusObjectPath('/org/freedesktop/login1/session/_31');
final _otherSession = DBusObjectPath('/org/freedesktop/login1/session/_42');
final _login1Path = DBusObjectPath('/org/freedesktop/login1');

/// `logind` en el bus de sistema: dice cuál es la sesión del proceso.
class _Login1 extends DBusObject {
  _Login1() : super(_login1Path);

  @override
  Future<DBusMethodResponse> handleMethodCall(DBusMethodCall call) async {
    if (call.name == 'GetSessionByPID' &&
        call.values.single == DBusUint32(pid)) {
      return DBusMethodSuccessResponse([_ownSession]);
    }
    return DBusMethodErrorResponse.unknownMethod();
  }
}

/// Un bus D-Bus en memoria, sobre TCP local.
Future<DBusAddress> _startBus() async {
  final server = DBusServer();
  addTearDown(server.close);
  return server.listenAddress(DBusAddress.tcp('127.0.0.1'));
}

/// Cliente de un bus de prueba (el servidor de prueba no comprueba el uid).
DBusClient _client(DBusAddress address) => DBusClient(
  address,
  authClient: DBusAuthClient(uid: '1000', requestUnixFd: false),
);

DBusClient _connect(DBusAddress address) {
  final client = _client(address);
  addTearDown(client.close);
  return client;
}

/// Bloquear la sesión, suspender o activar el salvapantallas bloquea la
/// bóveda en Linux (ADR 0012), con logind y los salvapantallas simulados.
void main() {
  late DBusClient login1;
  late DBusClient screenSaver;
  late LinuxOsSessionEventsAdapter adapter;
  late int requests;

  /// Emite [signal] hasta que la app lo recibe: las suscripciones se
  /// hacen en segundo plano al empezar a escuchar.
  Future<void> untilHeard(Future<void> Function() signal) async {
    final before = requests;
    final deadline = DateTime.now().add(const Duration(seconds: 5));
    while (requests == before) {
      if (DateTime.now().isAfter(deadline)) fail('la app no escuchó');
      await signal();
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
  }

  Future<void> untilCount(int count) async {
    final deadline = DateTime.now().add(const Duration(seconds: 5));
    while (requests < count && DateTime.now().isBefore(deadline)) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    // Margen para que llegue algo que no debería.
    await Future<void>.delayed(const Duration(milliseconds: 100));
  }

  Future<void> lock(DBusObjectPath session) => login1.emitSignal(
    path: session,
    interface: 'org.freedesktop.login1.Session',
    name: 'Lock',
  );

  Future<void> sleep(bool going) => login1.emitSignal(
    path: _login1Path,
    interface: 'org.freedesktop.login1.Manager',
    name: 'PrepareForSleep',
    values: [DBusBoolean(going)],
  );

  Future<void> screenSaverActive(String interface, bool active) =>
      screenSaver.emitSignal(
        path: DBusObjectPath('/org/cinnamon/ScreenSaver'),
        interface: interface,
        name: 'ActiveChanged',
        values: [DBusBoolean(active)],
      );

  Future<void> listen({
    required DBusClient Function() systemBus,
    required DBusClient Function() sessionBus,
  }) async {
    requests = 0;
    adapter = LinuxOsSessionEventsAdapter(
      systemBus: systemBus,
      sessionBus: sessionBus,
    );
    final subscription = adapter.lockRequests.listen((_) => requests++);
    addTearDown(() async {
      await subscription.cancel();
      await adapter.dispose();
    });
  }

  group('con logind', () {
    setUp(() async {
      final system = await _startBus();
      final session = await _startBus();
      login1 = _connect(system);
      await login1.requestName('org.freedesktop.login1');
      await login1.registerObject(_Login1());
      screenSaver = _connect(session);
      await listen(
        systemBus: () => _client(system),
        sessionBus: () => _client(session),
      );
    });

    test('bloquear la sesión propia y suspender bloquean; la sesión de otro '
        'usuario y despertar no', () async {
      await untilHeard(() => lock(_ownSession));
      requests = 0;

      await lock(_otherSession);
      await sleep(false);
      await sleep(true);
      await untilCount(1);

      expect(requests, 1);
    });

    test('el salvapantallas de Cinnamon, GNOME o freedesktop bloquea al '
        'activarse, no al desactivarse', () async {
      await untilHeard(
        () => screenSaverActive('org.cinnamon.ScreenSaver', true),
      );
      requests = 0;

      await screenSaverActive('org.gnome.ScreenSaver', false);
      await screenSaverActive('org.gnome.ScreenSaver', true);
      await screenSaverActive('org.freedesktop.ScreenSaver', true);
      await screenSaverActive('org.example.Otro', true);
      await untilCount(2);

      expect(requests, 2);
    });
  });

  test('sin logind (p. ej. lanzada desde un servicio) quedan los '
      'salvapantallas', () async {
    final system = await _startBus();
    final session = await _startBus();
    screenSaver = _connect(session);
    await listen(
      systemBus: () => _client(system),
      sessionBus: () => _client(session),
    );

    await untilHeard(
      () => screenSaverActive('org.freedesktop.ScreenSaver', true),
    );
  });

  test('sin ningún bus no hay avisos, y no falla', () async {
    await listen(
      systemBus: () => throw StateError('sin bus de sistema'),
      sessionBus: () => throw StateError('sin bus de sesión'),
    );
    await Future<void>.delayed(const Duration(milliseconds: 100));

    expect(requests, 0);
  });
}
