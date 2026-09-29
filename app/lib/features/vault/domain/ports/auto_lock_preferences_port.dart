// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Gabriel Ángel Montoya Rico

import '../auto_lock_timeout.dart';

/// Dónde se guarda el tiempo de bloqueo elegido. Vive fuera de la bóveda:
/// hace falta antes de desbloquearla, y no es un secreto.
abstract interface class AutoLockPreferencesPort {
  /// Nunca lanza: sin valor guardado o ilegible devuelve
  /// [AutoLockTimeout.defaultValue].
  Future<AutoLockTimeout> load();

  Future<void> save(AutoLockTimeout timeout);
}
