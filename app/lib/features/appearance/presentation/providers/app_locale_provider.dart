// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Gabriel Ángel Montoya Rico

import 'package:flutter/widgets.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../domain/appearance_preference.dart';
import '../appearance_controller.dart';

part 'app_locale_provider.g.dart';

/// Idioma elegido por el usuario, o `null` para seguir al sistema (ADR
/// 0032). Lo usan las dos `MaterialApp` (app y autocompletado).
@Riverpod(keepAlive: true)
Locale? appLocale(Ref ref) =>
    switch (ref.watch(appearanceControllerProvider).value?.language) {
      AppLanguage.es => const Locale('es'),
      AppLanguage.en => const Locale('en'),
      AppLanguage.system || null => null,
    };
