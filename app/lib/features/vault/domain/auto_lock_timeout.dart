// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Lockspire

/// Tiempos de bloqueo por inactividad que puede elegir el usuario (ADR
/// 0016). Solo estos tres: un valor libre permitiría dejar la bóveda
/// abierta indefinidamente.
enum AutoLockTimeout {
  oneMinute(Duration(minutes: 1)),
  fiveMinutes(Duration(minutes: 5)),
  fifteenMinutes(Duration(minutes: 15));

  final Duration duration;

  const AutoLockTimeout(this.duration);

  /// El de ADR 0008, que sigue siendo el valor por defecto.
  static const defaultValue = AutoLockTimeout.fiveMinutes;
}
