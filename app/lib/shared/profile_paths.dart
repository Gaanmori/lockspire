// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Gabriel Ángel Montoya Rico

import 'package:path/path.dart' as p;

import 'profile_scoped_secure_storage.dart';

const _vaultFileName = 'vault.lockspire';

/// La carpeta propia de un perfil que no es el principal (ADR 0039).
String profileDirectory(String appDataDirectory, String profileId) =>
    p.join(appDataDirectory, 'profiles', profileId);

/// El archivo de bóveda de un perfil: el principal conserva la ruta de
/// siempre; los demás, `profiles/<id>/`.
String vaultFilePathFor(String appDataDirectory, String profileId) =>
    profileId == mainProfileKeyId
    ? p.join(appDataDirectory, _vaultFileName)
    : p.join(profileDirectory(appDataDirectory, profileId), _vaultFileName);
