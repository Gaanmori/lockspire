// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Gabriel Ángel Montoya Rico

/// Sitios donde el usuario pidió "No preguntar en este sitio" al guardar
/// contraseñas desde el navegador (ADR 0034). Son de este equipo, no de la
/// bóveda: la lista no se sincroniza.
abstract class LoginSaveExclusionsPort {
  Future<bool> isExcluded(String site);

  Future<void> exclude(String site);

  /// Todos, para poder quitarlos desde la app.
  Future<Set<String>> all();

  Future<void> include(String site);
}
