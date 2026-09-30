// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Gabriel Ángel Montoya Rico

import 'package:path/path.dart' as p;

import 'domain/profile_ids.dart';

const _vaultFileName = 'vault.lockspire';

/// La carpeta propia de un perfil que no es el principal (ADR 0039).
/// Lanza [ArgumentError] con un id inválido o con el del principal, que no
/// tiene carpeta propia.
String profileDirectory(String appDataDirectory, String profileId) {
  if (profileId == mainProfileId) {
    throw ArgumentError.value(profileId, 'profileId', 'el principal no tiene');
  }
  return p.join(appDataDirectory, 'profiles', checkProfileId(profileId));
}

/// El archivo de bóveda de un perfil: el principal conserva la ruta de
/// siempre; los demás, `profiles/<id>/`.
String vaultFilePathFor(String appDataDirectory, String profileId) =>
    profileId == mainProfileId
    ? p.join(appDataDirectory, _vaultFileName)
    : p.join(profileDirectory(appDataDirectory, profileId), _vaultFileName);
