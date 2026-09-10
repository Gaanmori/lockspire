// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Lockspire

import 'package:googleapis_auth/googleapis_auth.dart' show AuthClient;

/// Resultado de una autenticación exitosa contra Google (interactiva o
/// silenciosa), de cualquiera de las dos plataformas
/// (`google_drive_android_auth.dart`/`google_drive_windows_auth.dart`).
///
/// [refreshToken] es `null` en Android (ver `GoogleDriveAccount`, el
/// motivo es el mismo) — solo Windows necesita guardarlo.
class GoogleDriveConnection {
  final String email;
  final String? refreshToken;
  final AuthClient httpClient;

  const GoogleDriveConnection({
    required this.email,
    required this.httpClient,
    this.refreshToken,
  });
}
