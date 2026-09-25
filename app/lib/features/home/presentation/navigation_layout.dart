// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Lockspire

/// Cómo se presenta la navegación principal según el ancho disponible.
enum NavigationLayout {
  /// Barra inferior (`NavigationBar`): ventanas compactas, como un teléfono
  /// en vertical.
  bar,

  /// Riel lateral (`NavigationRail`): tablets y escritorio.
  rail,
}

/// Límite de Material 3 entre ventana "compacta" y "mediana" (window size
/// classes).
const compactWidthBreakpoint = 600.0;

NavigationLayout navigationLayoutFor(double width) =>
    width < compactWidthBreakpoint
    ? NavigationLayout.bar
    : NavigationLayout.rail;
