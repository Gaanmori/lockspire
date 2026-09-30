// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Gabriel Ángel Montoya Rico

import 'dart:async';
import 'dart:io' show Platform;

import 'package:tray_manager/tray_manager.dart';

import '../domain/ports/tray_port.dart';

/// [TrayPort] con `tray_manager`. Clic izquierdo: abrir; clic derecho:
/// menú contextual. En Linux (AppIndicator) no hay tooltip.
class TrayManagerAdapter with TrayListener implements TrayPort {
  final _actions = StreamController<TrayAction>.broadcast();

  TrayManagerAdapter() {
    trayManager.addListener(this);
  }

  @override
  Stream<TrayAction> get actions => _actions.stream;

  @override
  Future<void> showDefaultIcon() => setIcon(
    Platform.isWindows
        ? 'assets/tray/tray_icon.ico'
        : 'assets/tray/tray_icon.png',
  );

  @override
  Future<void> setIcon(String path) async {
    await trayManager.setIcon(path);
    if (Platform.isWindows) await trayManager.setToolTip('Lockspire');
  }

  @override
  Future<void> setMenu(TrayMenu menu) => trayManager.setContextMenu(
    Menu(
      items: [
        MenuItem(key: TrayAction.open.name, label: menu.open),
        MenuItem(
          key: TrayAction.lock.name,
          label: menu.lock,
          disabled: !menu.lockEnabled,
        ),
        MenuItem.separator(),
        MenuItem(key: TrayAction.quit.name, label: menu.quit),
      ],
    ),
  );

  @override
  void onTrayIconMouseDown() => _actions.add(TrayAction.open);

  @override
  void onTrayIconRightMouseDown() => unawaited(trayManager.popUpContextMenu());

  @override
  void onTrayMenuItemClick(MenuItem menuItem) {
    final action = TrayAction.values.asNameMap()[menuItem.key];
    if (action != null) _actions.add(action);
  }

  @override
  Future<void> destroy() async {
    await dispose();
    await trayManager.destroy();
  }

  /// Deja de escuchar la bandeja sin quitarla. `trayManager` es global: al
  /// cambiar de perfil se crea otro adaptador (ADR 0039), y si este siguiera
  /// escuchando, cada clic derecho abriría el menú una vez por perfil
  /// abierto antes.
  Future<void> dispose() async {
    trayManager.removeListener(this);
    await _actions.close();
  }
}
