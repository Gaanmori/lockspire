// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Lockspire

import 'package:flutter/widgets.dart';

/// Una sección de la navegación principal. `HomeShell` no conoce ninguna
/// sección concreta: recibe la lista, así que añadir una nueva no toca la
/// shell (abierto a extensión, cerrado a modificación).
class HomeDestination {
  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final WidgetBuilder builder;

  const HomeDestination({
    required this.label,
    required this.icon,
    required this.selectedIcon,
    required this.builder,
  });
}
