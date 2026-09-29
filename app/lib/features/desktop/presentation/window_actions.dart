// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Gabriel Ángel Montoya Rico

import 'package:window_manager/window_manager.dart';

/// Muestra y enfoca la ventana principal (también si estaba oculta en la
/// bandeja, ADR 0012). Solo escritorio.
Future<void> showMainWindow() async {
  if (await windowManager.isMinimized()) await windowManager.restore();
  await windowManager.show();
  await windowManager.focus();
}
