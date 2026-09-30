// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Gabriel Ángel Montoya Rico

import 'dart:async';

import 'package:window_manager/window_manager.dart';

import '../domain/ports/desktop_window_port.dart';

/// [DesktopWindowPort] con `window_manager`. Necesita
/// `windowManager.ensureInitialized()` en `main()` antes de `runApp()`.
class WindowManagerAdapter with WindowListener implements DesktopWindowPort {
  final _closeRequests = StreamController<void>.broadcast();

  WindowManagerAdapter() {
    windowManager.addListener(this);
  }

  @override
  Stream<void> get closeRequests => _closeRequests.stream;

  @override
  void onWindowClose() => _closeRequests.add(null);

  @override
  Future<void> interceptClose(bool intercept) =>
      windowManager.setPreventClose(intercept);

  @override
  Future<void> show() async {
    if (await windowManager.isMinimized()) await windowManager.restore();
    await windowManager.show();
    await windowManager.focus();
  }

  @override
  Future<void> hide() => windowManager.hide();

  @override
  Future<void> setIcon(String path) => windowManager.setIcon(path);

  @override
  Future<void> destroy() async {
    await dispose();
    await windowManager.destroy();
  }

  /// Deja de escuchar la ventana sin cerrarla. `windowManager` es global:
  /// ver `TrayManagerAdapter.dispose`.
  Future<void> dispose() async {
    windowManager.removeListener(this);
    await _closeRequests.close();
  }
}
