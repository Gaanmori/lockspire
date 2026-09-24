// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Lockspire

/// Cuándo se desbloqueó por última vez **con la contraseña maestra** en
/// este dispositivo (ADR 0017). Separado del ajuste de días: se escribe en
/// cada desbloqueo, el ajuste solo cuando el usuario lo cambia.
abstract interface class PasswordUnlockHistoryPort {
  /// `null` si nunca se registró o no se puede leer: la regla lo trata como
  /// "hay que pedir la contraseña".
  Future<DateTime?> lastPasswordUnlock();

  Future<void> recordPasswordUnlock(DateTime at);
}
