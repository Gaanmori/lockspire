// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Lockspire

/// Cada cuánto se exige la contraseña maestra aunque el desbloqueo
/// biométrico esté activo (ADR 0017).
enum MasterPasswordReminder {
  sevenDays(Duration(days: 7)),
  fourteenDays(Duration(days: 14)),
  thirtyDays(Duration(days: 30));

  final Duration interval;

  const MasterPasswordReminder(this.interval);

  static const defaultValue = MasterPasswordReminder.fourteenDays;
}

/// Regla pura (ADR 0017): ¿hay que pedir la contraseña maestra en vez de
/// ofrecer huella/Windows Hello?
///
/// - Sin registro de un desbloqueo con contraseña en este dispositivo
///   ([lastPasswordUnlock] `null`): sí. Cubre también a quien ya tenía la
///   biometría activa antes de que existiera esta regla.
/// - Registro en el futuro (el reloj se atrasó, a mano o por error): sí.
///   Atrasar el reloj nunca puede alargar el plazo.
/// - Si pasó el [interval] completo: sí.
bool isMasterPasswordRequiredAt({
  required DateTime? lastPasswordUnlock,
  required DateTime now,
  required Duration interval,
}) {
  if (lastPasswordUnlock == null) return true;
  if (lastPasswordUnlock.isAfter(now)) return true;
  return now.difference(lastPasswordUnlock) >= interval;
}
