// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Lockspire

import '../appearance_preference.dart';

/// Dónde se guarda la preferencia de tema. No es un secreto, pero vive
/// fuera de la bóveda: el tema se aplica también en la pantalla de
/// desbloqueo, antes de tener la clave.
abstract interface class AppearancePreferencesPort {
  /// Nunca lanza: si no hay nada guardado o no se puede leer, devuelve
  /// [AppearancePreference.defaults].
  Future<AppearancePreference> load();

  Future<void> save(AppearancePreference preference);
}
