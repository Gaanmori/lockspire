// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Lockspire

/// Eventos de la sesión del sistema operativo que obligan a bloquear la
/// bóveda de inmediato en escritorio: bloqueo de pantalla/sesión y
/// suspensión (ADR 0012, disparador 3).
///
/// Cada adaptador escucha lo que su plataforma ofrece; si no detecta nada
/// (entorno sin esos servicios) simplemente no emite — la inactividad y el
/// bloqueo manual siguen cubriendo el caso.
abstract interface class OsSessionEventsPort {
  /// Emite un evento cada vez que la sesión del SO se bloquea o el equipo
  /// va a suspenderse. Stream broadcast; la suscripción empieza a escuchar
  /// al SO (idempotente).
  Stream<void> get lockRequests;

  /// Deja de escuchar al SO y cierra el stream.
  Future<void> dispose();
}
