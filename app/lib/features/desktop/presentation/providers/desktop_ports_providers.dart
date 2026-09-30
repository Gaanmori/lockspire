// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Gabriel Ángel Montoya Rico

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../domain/ports/desktop_window_port.dart';
import '../../domain/ports/themed_icon_file_port.dart';
import '../../domain/ports/tray_port.dart';
import '../../infrastructure/themed_icon_file_adapter.dart';
import '../../infrastructure/tray_manager_adapter.dart';
import '../../infrastructure/window_manager_adapter.dart';

part 'desktop_ports_providers.g.dart';

/// Solo se leen en escritorio (`isDesktopShellProvider`): fuera de él los
/// plugins no están inicializados.
/// La ventana y la bandeja son del proceso, pero cada perfil tiene su
/// contenedor (ADR 0039): al descartarlo, su adaptador deja de escuchar.
@Riverpod(keepAlive: true)
DesktopWindowPort desktopWindowPort(Ref ref) {
  final window = WindowManagerAdapter();
  ref.onDispose(window.dispose);
  return window;
}

@Riverpod(keepAlive: true)
TrayPort trayPort(Ref ref) {
  final tray = TrayManagerAdapter();
  ref.onDispose(tray.dispose);
  return tray;
}

@Riverpod(keepAlive: true)
ThemedIconFilePort themedIconFilePort(Ref ref) => const ThemedIconFileAdapter();
