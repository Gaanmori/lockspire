// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Gabriel Ángel Montoya Rico

/// La ventana principal en escritorio (ADR 0012).
abstract class DesktopWindowPort {
  /// El usuario pidió cerrar la ventana (la X). Con [interceptClose] activo,
  /// la ventana no se cierra sola: decide quien escucha.
  Stream<void> get closeRequests;

  Future<void> interceptClose(bool intercept);

  /// Muestra y enfoca la ventana, también si estaba minimizada u oculta.
  Future<void> show();

  Future<void> hide();

  /// Ícono de la ventana y de la barra de tareas (archivo en disco).
  Future<void> setIcon(String path);

  /// Cierra la ventana de verdad y termina la app.
  Future<void> destroy();
}
