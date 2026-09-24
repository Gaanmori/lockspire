// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Lockspire

import 'dart:async';
import 'dart:io' show pid;

import 'package:dbus/dbus.dart';

import '../domain/ports/os_session_events_port.dart';

/// Salvapantallas que exponen `ActiveChanged(bool)` en el bus de sesión.
/// Cinnamon es el de Linux Mint; freedesktop lo implementan KDE y otros.
const _screenSaverInterfaces = [
  'org.freedesktop.ScreenSaver',
  'org.gnome.ScreenSaver',
  'org.cinnamon.ScreenSaver',
];

/// [OsSessionEventsPort] en Linux vía D-Bus (ADR 0012):
///
/// - Bus de sistema, `org.freedesktop.login1`: señal `Lock` de la sesión
///   de este proceso y `PrepareForSleep(true)` del `Manager`.
/// - Bus de sesión: `ActiveChanged(true)` de los salvapantallas conocidos.
///
/// Todo es best-effort: si un bus o servicio no existe (entorno sin
/// logind, sin salvapantallas), esa fuente se ignora sin error. Solo se
/// escucha la sesión propia en login1 — no las de otros usuarios del
/// equipo, que también emiten `Lock` en el bus de sistema.
class LinuxOsSessionEventsAdapter implements OsSessionEventsPort {
  final _controller = StreamController<void>.broadcast();
  final _subscriptions = <StreamSubscription<DBusSignal>>[];
  DBusClient? _systemBus;
  DBusClient? _sessionBus;
  bool _started = false;

  @override
  Stream<void> get lockRequests {
    if (!_started) {
      _started = true;
      unawaited(_start());
    }
    return _controller.stream;
  }

  Future<void> _start() async {
    await _listenLogind();
    _listenScreenSavers();
  }

  Future<void> _listenLogind() async {
    try {
      final bus = _systemBus = DBusClient.system();
      final login1 = DBusRemoteObject(
        bus,
        name: 'org.freedesktop.login1',
        path: DBusObjectPath('/org/freedesktop/login1'),
      );

      _subscriptions.add(
        DBusSignalStream(
          bus,
          sender: 'org.freedesktop.login1',
          interface: 'org.freedesktop.login1.Manager',
          name: 'PrepareForSleep',
          signature: DBusSignature('b'),
        ).listen((signal) {
          if (signal.values.first.asBoolean()) _controller.add(null);
        }, onError: (_) {}),
      );

      final session = await login1.callMethod(
        'org.freedesktop.login1.Manager',
        'GetSessionByPID',
        [DBusUint32(pid)],
        replySignature: DBusSignature('o'),
      );
      final sessionPath = session.values.first.asObjectPath();
      _subscriptions.add(
        DBusSignalStream(
          bus,
          sender: 'org.freedesktop.login1',
          interface: 'org.freedesktop.login1.Session',
          name: 'Lock',
          path: sessionPath,
        ).listen((_) => _controller.add(null), onError: (_) {}),
      );
    } catch (_) {
      // Sin logind, o el proceso no pertenece a ninguna sesión (p. ej.
      // lanzado desde un servicio). Quedan los salvapantallas.
    }
  }

  void _listenScreenSavers() {
    try {
      final bus = _sessionBus = DBusClient.session();
      for (final interface in _screenSaverInterfaces) {
        _subscriptions.add(
          DBusSignalStream(
            bus,
            interface: interface,
            name: 'ActiveChanged',
            signature: DBusSignature('b'),
          ).listen((signal) {
            if (signal.values.first.asBoolean()) _controller.add(null);
          }, onError: (_) {}),
        );
      }
    } catch (_) {
      // Sin bus de sesión (no debería pasar en un escritorio real).
    }
  }

  @override
  Future<void> dispose() async {
    for (final s in _subscriptions) {
      await s.cancel();
    }
    _subscriptions.clear();
    await _systemBus?.close();
    await _sessionBus?.close();
    await _controller.close();
  }
}
