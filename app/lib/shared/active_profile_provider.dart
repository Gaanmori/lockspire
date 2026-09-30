// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Gabriel Ángel Montoya Rico

import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'domain/profile_ids.dart';

part 'active_profile_provider.g.dart';

/// El perfil abierto (ADR 0039). Cada `ProviderContainer` es de un solo
/// perfil: `bootProfile` lo fija con un override al crearlo, y cambiar de
/// perfil crea otro contenedor. Sin override, el principal.
@Riverpod(keepAlive: true)
String activeProfileId(Ref ref) => mainProfileId;
