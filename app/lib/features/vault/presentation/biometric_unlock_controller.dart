// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Gabriel Ángel Montoya Rico

import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'providers/biometric_auth_port_provider.dart';
import 'vault_session_controller.dart';
import 'vault_session_state.dart';

part 'biometric_unlock_controller.g.dart';

@Riverpod(keepAlive: true)
BiometricUnlockController biometricUnlockController(Ref ref) =>
    BiometricUnlockController(ref);

/// Activar o desactivar el desbloqueo biométrico (ADR 0010). Separado de
/// `VaultSessionController` (revisión 2026-09-25, hallazgo A1): desbloquear
/// con biometría sigue siendo parte de la sesión; esto es configuración.
class BiometricUnlockController {
  final Ref _ref;

  BiometricUnlockController(this._ref);

  /// Cachea la clave de la sesión actual detrás de la biometría/PIN del
  /// sistema. Solo con la bóveda desbloqueada (justo después de un
  /// desbloqueo real con contraseña); si no lo está, no hace nada.
  Future<void> enable() async {
    final session = _ref.read(vaultSessionControllerProvider).value;
    if (session is! VaultSessionUnlocked) return;
    await _ref.read(biometricAuthPortProvider).storeKey(key: session.key);
  }

  /// Borra la clave cacheada.
  Future<void> disable() => _ref.read(biometricAuthPortProvider).deleteKey();
}
