// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Gabriel Ángel Montoya Rico

import 'dart:async';

import 'package:lockspire/shared/platform_capabilities.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../domain/appearance_preference.dart';
import 'appearance_controller.dart';
import 'providers/launcher_icon_port_provider.dart';

part 'launcher_icon_sync.g.dart';

/// En Android, el ícono de Lockspire en el lanzador sigue al tema elegido
/// (ADR 0031): Kotlin activa el alias con el ícono de ese tema. Se
/// instancia al arrancar la app (`main.dart`), así también se corrige si
/// el tema cambió en otra versión.
@Riverpod(keepAlive: true)
void launcherIconSync(Ref ref) {
  if (!ref.watch(platformCapabilitiesProvider).isAndroid) return;
  ref.listen<AsyncValue<AppearancePreference>>(appearanceControllerProvider, (
    _,
    next,
  ) {
    final family = next.value?.family;
    if (family == null) return;
    unawaited(ref.read(launcherIconPortProvider).useThemeIcon(family));
  }, fireImmediately: true);
}
