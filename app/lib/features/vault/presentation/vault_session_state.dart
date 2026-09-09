// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Lockspire

import '../domain/entities/vault.dart';

/// Estado de la sesión de bóveda en la UI.
///
/// Los estados de carga/error de las operaciones (crear, desbloquear) los
/// maneja el `AsyncValue` del propio [VaultSessionController] — no se
/// duplican aquí.
sealed class VaultSessionState {
  const VaultSessionState();
}

/// No existe todavía un archivo de bóveda — hay que crear uno.
class VaultSessionNoVault extends VaultSessionState {
  const VaultSessionNoVault();
}

/// Existe un archivo de bóveda pero no está desbloqueada.
class VaultSessionLocked extends VaultSessionState {
  const VaultSessionLocked();
}

/// La bóveda está desbloqueada; [vault] es su contenido desencriptado.
class VaultSessionUnlocked extends VaultSessionState {
  final Vault vault;
  const VaultSessionUnlocked(this.vault);
}
