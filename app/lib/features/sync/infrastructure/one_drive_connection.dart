// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Gabriel Ángel Montoya Rico

/// Resultado de una autenticación exitosa contra Microsoft (interactiva o
/// vía refresh token), ver `microsoft_oauth_auth.dart`.
///
/// A diferencia de `GoogleDriveConnection` (que carga un `AuthClient` ya
/// armado), acá alcanza con el `accessToken` en crudo — `OneDriveSyncAdapter`
/// usa `package:http` liso con un header `Authorization: Bearer` a mano,
/// no hace falta ningún wrapper de cliente auto-refrescante (ver el plan
/// aprobado: se pide un access token fresco por cada construcción de
/// `activeSyncPort`, las operaciones son cortas).
class OneDriveConnection {
  final String email;
  final String refreshToken;
  final String accessToken;

  const OneDriveConnection({
    required this.email,
    required this.refreshToken,
    required this.accessToken,
  });
}
