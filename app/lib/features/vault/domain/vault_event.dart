// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Lockspire

/// Lo que pasa en la sesión de la bóveda y puede interesarle a otras
/// features. `vault` los publica sin saber quién escucha: así `sync` reacciona
/// sin que `vault` dependa de ella (revisión 2026-09-25, hallazgo A3).
enum VaultEvent {
  /// Se abrió la sesión (bóveda creada, desbloqueada o restaurada).
  unlocked,

  /// Se guardó un cambio hecho en este dispositivo.
  saved,

  /// Se cerró la sesión.
  locked,

  /// Está por cambiar la clave (cambio de contraseña maestra, ADR 0018): lo
  /// pendiente con la clave vieja se descarta.
  rekeying,
}
