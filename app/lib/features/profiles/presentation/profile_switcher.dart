// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Gabriel Ángel Montoya Rico

/// Abre otro perfil reconstruyendo toda la app (ADR 0039): se bloquea la
/// sesión, se descarta el contenedor del perfil actual y se arranca uno
/// nuevo para [profileId]. Lo implementa `ProfileHost`, en la raíz.
abstract class ProfileSwitcher {
  /// [afterLeaving] corre con el perfil anterior ya descartado y antes de
  /// abrir el nuevo: ahí se borran los datos de un perfil eliminado.
  Future<void> open(String profileId, {Future<void> Function()? afterLeaving});
}
