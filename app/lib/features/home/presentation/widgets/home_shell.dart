// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Lockspire

import 'package:flutter/material.dart';

import '../home_destination.dart';
import '../navigation_layout.dart';

/// Navegación principal de Material 3 tras desbloquear: barra inferior en
/// ventanas compactas, riel lateral en las demás (ver
/// [navigationLayoutFor]).
///
/// Solo se encarga de la navegación: las secciones llegan en
/// [destinations] y la acción de bloquear en [onLock]. Cada sección
/// conserva su estado al cambiar de pestaña (`IndexedStack`). Al bloquear
/// la bóveda la shell se destruye, así que el próximo desbloqueo empieza de
/// nuevo en la primera sección.
class HomeShell extends StatefulWidget {
  final List<HomeDestination> destinations;
  final VoidCallback onLock;

  /// Aviso global opcional sobre el contenido (p. ej. la contraseña
  /// maestra se cambió en otro dispositivo). Debe ocupar cero espacio
  /// cuando no hay nada que avisar.
  final Widget? banner;

  const HomeShell({
    super.key,
    required this.destinations,
    required this.onLock,
    this.banner,
  }) : assert(destinations.length >= 2, 'M3 pide al menos 2 destinos');

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _selected = 0;

  void _select(int index) => setState(() => _selected = index);

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final layout = navigationLayoutFor(constraints.maxWidth);
        final pages = IndexedStack(
          index: _selected,
          children: [
            for (final destination in widget.destinations)
              Builder(
                builder: (context) => destination.builder(context, layout),
              ),
          ],
        );
        final banner = widget.banner;
        final body = banner == null
            ? pages
            : Column(
                children: [
                  SafeArea(bottom: false, child: banner),
                  Expanded(child: pages),
                ],
              );
        return switch (layout) {
          NavigationLayout.bar => Scaffold(
            body: body,
            bottomNavigationBar: NavigationBar(
              selectedIndex: _selected,
              onDestinationSelected: _select,
              destinations: [
                for (final d in widget.destinations)
                  NavigationDestination(
                    icon: Icon(d.icon),
                    selectedIcon: Icon(d.selectedIcon),
                    label: d.label,
                  ),
              ],
            ),
          ),
          NavigationLayout.rail => Scaffold(
            body: Row(
              children: [
                NavigationRail(
                  selectedIndex: _selected,
                  onDestinationSelected: _select,
                  labelType: NavigationRailLabelType.all,
                  destinations: [
                    for (final d in widget.destinations)
                      NavigationRailDestination(
                        icon: Icon(d.icon),
                        selectedIcon: Icon(d.selectedIcon),
                        label: Text(d.label),
                      ),
                  ],
                  trailing: Expanded(
                    child: Align(
                      alignment: Alignment.bottomCenter,
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: IconButton(
                          icon: const Icon(Icons.lock_outline),
                          tooltip: 'Bloquear',
                          onPressed: widget.onLock,
                        ),
                      ),
                    ),
                  ),
                ),
                const VerticalDivider(width: 1, thickness: 1),
                Expanded(child: body),
              ],
            ),
          ),
        };
      },
    );
  }
}
