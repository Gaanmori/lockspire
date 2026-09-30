// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Gabriel Ángel Montoya Rico

import 'dart:io' show Platform;

/// La versión que se publica en Google Play se compila con
/// `--dart-define=LOCKSPIRE_STORE=play`; ahí se dona con su facturación.
const _store = String.fromEnvironment('LOCKSPIRE_STORE');

bool get isGooglePlayBuild => _store == 'play' && Platform.isAndroid;
