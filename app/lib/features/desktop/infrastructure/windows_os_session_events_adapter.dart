// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Gabriel Ángel Montoya Rico

import 'dart:async';

import 'package:flutter/services.dart';

import '../domain/ports/os_session_events_port.dart';

/// Nombre del canal que usa el runner nativo de Windows
/// (`windows/runner/flutter_window.cpp`) para reenviar
/// `WTS_SESSION_LOCK` y `PBT_APMSUSPEND`.
const osSessionChannelName = 'com.lockspire/os_session';

/// [OsSessionEventsPort] en Windows. La detección vive en C++ (el runner
/// ya recibe los mensajes de la ventana: `WM_WTSSESSION_CHANGE`,
/// `WM_POWERBROADCAST`); acá solo se traduce la llamada del canal a un
/// evento del stream.
class WindowsOsSessionEventsAdapter implements OsSessionEventsPort {
  final MethodChannel _channel;
  final _controller = StreamController<void>.broadcast();

  WindowsOsSessionEventsAdapter({MethodChannel? channel})
    : _channel = channel ?? const MethodChannel(osSessionChannelName) {
    _channel.setMethodCallHandler(_handle);
  }

  Future<void> _handle(MethodCall call) async {
    // Métodos emitidos por el runner: `sessionLocked`, `suspending`. Ambos
    // significan lo mismo para la bóveda.
    if (call.method == 'sessionLocked' || call.method == 'suspending') {
      _controller.add(null);
    }
  }

  @override
  Stream<void> get lockRequests => _controller.stream;

  @override
  Future<void> dispose() async {
    _channel.setMethodCallHandler(null);
    await _controller.close();
  }
}
