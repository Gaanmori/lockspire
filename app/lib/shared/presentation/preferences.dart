// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Gabriel Ángel Montoya Rico

/// Guarda una preferencia que ya se aplicó en memoria. Si guardar falla
/// (almacenamiento seguro no disponible), la elección dura hasta cerrar la
/// app y al volver a abrirla queda la anterior: no vale la pena interrumpir
/// al usuario por un ajuste. Una sola regla para todas las preferencias
/// (revisión 2026-09-30).
Future<void> saveAppliedPreference(Future<void> Function() save) async {
  try {
    await save();
  } catch (_) {
    // Ver arriba: la preferencia sigue aplicada en esta sesión.
  }
}
