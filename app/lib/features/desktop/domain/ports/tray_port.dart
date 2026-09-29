// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Gabriel Ángel Montoya Rico

/// Lo que el usuario eligió en el ícono de la bandeja.
enum TrayAction { open, lock, quit }

/// Textos del menú de la bandeja, ya en el idioma de la app.
class TrayMenu {
  final String open;
  final String lock;
  final String quit;

  /// "Bloquear" solo tiene sentido con la bóveda abierta.
  final bool lockEnabled;

  const TrayMenu({
    required this.open,
    required this.lock,
    required this.quit,
    required this.lockEnabled,
  });
}

/// El ícono de la app en la bandeja del sistema (ADR 0012). Un clic sobre el
/// ícono es [TrayAction.open]; el menú contextual es cosa del adaptador.
abstract class TrayPort {
  Stream<TrayAction> get actions;

  /// El ícono que trae la app instalada, hasta tener el del tema.
  Future<void> showDefaultIcon();

  /// Ícono del tema (archivo en disco).
  Future<void> setIcon(String path);

  Future<void> setMenu(TrayMenu menu);

  Future<void> destroy();
}
