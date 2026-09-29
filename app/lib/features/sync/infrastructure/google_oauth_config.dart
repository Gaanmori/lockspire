// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Gabriel Ángel Montoya Rico

/// Config de los clientes OAuth de Google Cloud Console usados por Fase 8.
/// Se inyectan en tiempo de compilación:
///
/// ```
/// flutter run --dart-define-from-file=google_oauth_secrets.json
/// ```
///
/// con un `google_oauth_secrets.json` local (gitignored, ver
/// `google_oauth_secrets.json.example`).
class GoogleOAuthConfig {
  /// Client id/secret del cliente OAuth tipo "Desktop app", usado solo en
  /// escritorio, Windows y Linux (ver `google_drive_desktop_auth.dart`) —
  /// el secret de un
  /// cliente "Desktop" no es confidencial por diseño de Google, pero
  /// igual no se comitea en texto plano.
  static const clientId = String.fromEnvironment('GOOGLE_OAUTH_CLIENT_ID');
  static const clientSecret = String.fromEnvironment(
    'GOOGLE_OAUTH_CLIENT_SECRET',
  );

  /// Client id de un cliente OAuth tipo **"Aplicación web"** (no el
  /// "Android" que ya existe) — `google_sign_in` en Android (vía
  /// Credential Manager) lo exige como `serverClientId` en
  /// `initialize()`, aunque Lockspire no tenga backend propio. Es un
  /// identificador público, no un secreto (Google lo documenta así), pero
  /// igual se inyecta por el mismo mecanismo por consistencia.
  static const androidServerClientId = String.fromEnvironment(
    'GOOGLE_OAUTH_ANDROID_SERVER_CLIENT_ID',
  );

  static bool get isConfigured => clientId.isNotEmpty;
}
