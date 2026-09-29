// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Gabriel Ángel Montoya Rico

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../domain/appearance_preference.dart';
import '../appearance_controller.dart';
import '../appearance_theme.dart';
import 'system_accent_color_provider.dart';

part 'app_themes_provider.g.dart';

/// Temas claro/oscuro y modo que aplica `MaterialApp`, a partir de la
/// preferencia del usuario y del color del sistema. Único punto que
/// combina ambos.
@Riverpod(keepAlive: true)
AppThemes appThemes(Ref ref) => resolveAppThemes(
  ref.watch(appearanceControllerProvider).value ??
      AppearancePreference.defaults,
  ref.watch(systemAccentColorProvider).value,
);
