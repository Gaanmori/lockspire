// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Gabriel Ángel Montoya Rico

import 'package:flutter/widgets.dart';

import 'generated/app_localizations.dart';

export 'generated/app_localizations.dart';

/// Acceso corto a los textos traducidos (ADR 0032): `context.l10n.clave`.
extension L10nContext on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);
}

/// Español si el sistema está en español; inglés en cualquier otro caso
/// (ADR 0032).
Locale resolveSystemLocale(Iterable<Locale>? systemLocales) {
  for (final locale in systemLocales ?? const <Locale>[]) {
    if (locale.languageCode == 'es') return const Locale('es');
    if (locale.languageCode == 'en') return const Locale('en');
  }
  return const Locale('en');
}
