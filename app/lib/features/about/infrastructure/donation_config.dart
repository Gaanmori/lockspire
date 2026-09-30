// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Gabriel Ángel Montoya Rico

import 'dart:io' show Platform;

/// La tienda de esta compilación: `--dart-define=LOCKSPIRE_STORE=play` en
/// Google Play y `=msstore` en Microsoft Store. Ahí se dona con el pago de
/// cada tienda (ADR 0033, 0035); en las demás compilaciones no se ofrece.
const _store = String.fromEnvironment('LOCKSPIRE_STORE');

bool get isGooglePlayBuild => _store == 'play' && Platform.isAndroid;

bool get isMicrosoftStoreBuild => _store == 'msstore' && Platform.isWindows;
