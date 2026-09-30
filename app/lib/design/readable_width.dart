// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Gabriel Ángel Montoya Rico

import 'package:flutter/widgets.dart';

/// Una columna de ancho legible, arriba y al centro. En el teléfono no
/// cambia nada; en escritorio, las pantallas de ajustes dejan de estirarse
/// de lado a lado (encontrado al hacer las capturas de Microsoft Store,
/// 2026-09-30: las vistas previas de los temas se deformaban).
class ReadableWidth extends StatelessWidget {
  /// Ancho de las pantallas de ajustes: como la lista de la bóveda.
  static const settings = 760.0;

  final double maxWidth;
  final Widget child;

  const ReadableWidth({
    super.key,
    this.maxWidth = settings,
    required this.child,
  });

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.topCenter,
    child: ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: child,
    ),
  );
}
