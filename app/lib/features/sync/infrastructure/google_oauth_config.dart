// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Lockspire

/// Client id/secret del cliente OAuth "Desktop app" de Google Cloud
/// Console, usado solo en Windows (ver `google_drive_windows_auth.dart`
/// y docs/STATE.md Fase 8 — el secret de un cliente "Desktop" no es
/// confidencial por diseño de Google, pero igual no se comitea en texto
/// plano). Se inyectan en tiempo de compilación:
///
/// ```
/// flutter run --dart-define-from-file=google_oauth_secrets.json
/// ```
///
/// con un `google_oauth_secrets.json` local (gitignored, ver
/// `google_oauth_secrets.json.example`) con las keys
/// `GOOGLE_OAUTH_CLIENT_ID`/`GOOGLE_OAUTH_CLIENT_SECRET`.
class GoogleOAuthConfig {
  static const clientId = String.fromEnvironment('GOOGLE_OAUTH_CLIENT_ID');
  static const clientSecret = String.fromEnvironment(
    'GOOGLE_OAUTH_CLIENT_SECRET',
  );

  static bool get isConfigured => clientId.isNotEmpty;
}
