// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Gabriel Ángel Montoya Rico

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../design/lockspire_colors.dart';
import '../../../../design/lockspire_icon.dart';
import 'app_themes_provider.dart';

part 'app_icon_colors_provider.g.dart';

/// Colores del ícono de Lockspire para el tema elegido: salen de su versión
/// clara (ver [LockspireIconColors.fromPalette]). Los usan el ícono dentro
/// de la app, la ventana y la bandeja de escritorio.
@Riverpod(keepAlive: true)
LockspireIconColors appIconColors(Ref ref) {
  final light = ref.watch(appThemesProvider).light;
  final palette = light.extension<LockspirePalette>();
  return palette == null
      ? LockspireIconColors.grafito
      : LockspireIconColors.fromPalette(palette);
}
