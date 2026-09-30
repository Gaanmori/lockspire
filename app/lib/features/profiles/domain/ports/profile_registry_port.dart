// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Gabriel Ángel Montoya Rico

import '../profile_registry.dart';

/// Dónde se guarda la lista de perfiles del dispositivo (ADR 0039).
abstract class ProfileRegistryPort {
  /// [mainName]: el nombre del perfil principal si todavía no hay nada
  /// guardado (la instalación de siempre).
  Future<ProfileRegistry> load({required String mainName});

  Future<void> save(ProfileRegistry registry);
}
