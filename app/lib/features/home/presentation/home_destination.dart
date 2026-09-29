// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Gabriel Ángel Montoya Rico

import 'package:flutter/widgets.dart';

import 'navigation_layout.dart';

/// Construye el contenido de una sección. Recibe la disposición activa
/// para que la sección no duplique lo que ya ofrece la navegación (p. ej.
/// Bloquear, que en el riel ya está al pie).
typedef HomeDestinationBuilder =
    Widget Function(BuildContext context, NavigationLayout layout);

/// Una sección de la navegación principal. `HomeShell` no conoce ninguna
/// sección concreta: recibe la lista, así que añadir una nueva no toca la
/// shell (abierto a extensión, cerrado a modificación).
class HomeDestination {
  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final HomeDestinationBuilder builder;

  const HomeDestination({
    required this.label,
    required this.icon,
    required this.selectedIcon,
    required this.builder,
  });
}
