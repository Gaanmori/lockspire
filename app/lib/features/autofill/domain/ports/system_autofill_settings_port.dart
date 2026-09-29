// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Gabriel Ángel Montoya Rico

/// Los ajustes del sistema donde se elige el servicio de autocompletado
/// (Android).
abstract class SystemAutofillSettingsPort {
  /// `false` si el sistema no pudo abrirlos.
  Future<bool> open();
}
