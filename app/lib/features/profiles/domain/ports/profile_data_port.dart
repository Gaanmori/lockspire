// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Gabriel Ángel Montoya Rico

/// Los datos de un perfil fuera de la lista: su bóveda y sus claves del
/// almacenamiento seguro (ADR 0039).
abstract class ProfileDataPort {
  /// Borra todo lo del perfil [id]. Nunca el principal.
  Future<void> erase(String id);
}
