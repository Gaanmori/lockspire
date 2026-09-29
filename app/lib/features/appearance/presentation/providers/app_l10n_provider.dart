// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Gabriel Ángel Montoya Rico

import 'dart:ui';

import 'package:lockspire/l10n/l10n.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'app_locale_provider.dart';

part 'app_l10n_provider.g.dart';

/// Textos del idioma activo para quien no tiene un `BuildContext`: la raíz
/// de composición, que se los pasa a adaptadores como el diálogo de huella
/// del sistema (ADR 0032). Sigue el mismo criterio que las `MaterialApp`.
@Riverpod(keepAlive: true)
AppLocalizations appL10n(Ref ref) => lookupAppLocalizations(
  ref.watch(appLocaleProvider) ??
      resolveSystemLocale(PlatformDispatcher.instance.locales),
);
