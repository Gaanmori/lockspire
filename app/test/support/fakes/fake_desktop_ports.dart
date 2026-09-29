// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Gabriel Ángel Montoya Rico

import 'dart:async';

import 'package:lockspire/design/lockspire_icon.dart';
import 'package:lockspire/features/desktop/domain/ports/desktop_window_port.dart';
import 'package:lockspire/features/desktop/domain/ports/os_session_events_port.dart';
import 'package:lockspire/features/desktop/domain/ports/themed_icon_file_port.dart';
import 'package:lockspire/features/desktop/domain/ports/tray_port.dart';

/// Ventana de escritorio en memoria. [requestClose] simula la X.
class FakeDesktopWindow implements DesktopWindowPort {
  final _closeRequests = StreamController<void>.broadcast();
  bool intercepting = false;
  bool visible = true;
  bool destroyed = false;
  String? icon;

  void requestClose() => _closeRequests.add(null);

  @override
  Stream<void> get closeRequests => _closeRequests.stream;

  @override
  Future<void> interceptClose(bool intercept) async => intercepting = intercept;

  @override
  Future<void> show() async => visible = true;

  @override
  Future<void> hide() async => visible = false;

  @override
  Future<void> setIcon(String path) async => icon = path;

  @override
  Future<void> destroy() async => destroyed = true;
}

/// Bandeja en memoria. [choose] simula elegir una acción del ícono o menú.
class FakeTray implements TrayPort {
  final _actions = StreamController<TrayAction>.broadcast();
  TrayMenu? menu;
  String? icon;
  bool destroyed = false;

  void choose(TrayAction action) => _actions.add(action);

  @override
  Stream<TrayAction> get actions => _actions.stream;

  @override
  Future<void> showDefaultIcon() async => icon = 'default';

  @override
  Future<void> setIcon(String path) async => icon = path;

  @override
  Future<void> setMenu(TrayMenu menu) async => this.menu = menu;

  @override
  Future<void> destroy() async => destroyed = true;
}

/// Devuelve una ruta distinta por combinación de colores, sin tocar disco.
class FakeThemedIconFile implements ThemedIconFilePort {
  @override
  Future<String> write(LockspireIconColors colors) async =>
      'icon-${colors.background.toARGB32().toRadixString(16)}';
}

/// La sesión del sistema: [lockSession] simula bloquearla o suspender.
class FakeOsSessionEvents implements OsSessionEventsPort {
  final _lockRequests = StreamController<void>.broadcast();

  void lockSession() => _lockRequests.add(null);

  @override
  Stream<void> get lockRequests => _lockRequests.stream;

  @override
  Future<void> dispose() => _lockRequests.close();
}
