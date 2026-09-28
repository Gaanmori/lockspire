// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Lockspire

import 'package:lockspire/shared/platform_capabilities.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'lock_on_background_provider.g.dart';

/// Si pasar a segundo plano (`AppLifecycleState.paused`/`.hidden`)
/// bloquea la bóveda de inmediato.
///
/// - Android: sí (ADR 0008).
/// - Escritorio (Windows, Linux): no — la app vive en la bandeja para que
///   la extensión de navegador pueda usarla, y en su lugar se bloquea por
///   inactividad, manualmente o con la sesión del SO (ADR 0012).
///
/// Sobreescribible en tests.
@Riverpod(keepAlive: true)
bool lockOnBackground(Ref ref) =>
    !ref.watch(platformCapabilitiesProvider).isDesktop;
