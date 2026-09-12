// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Lockspire

/// Config del Azure App Registration usado por el proveedor de sync
/// OneDrive (ver `microsoft_oauth_auth.dart`). Se inyecta en tiempo de
/// compilación:
///
/// ```
/// flutter run --dart-define-from-file=microsoft_oauth_secrets.json
/// ```
///
/// con un `microsoft_oauth_secrets.json` local (gitignored, ver
/// `microsoft_oauth_secrets.json.example`) — mismo mecanismo que
/// `google_oauth_config.dart`.
class MicrosoftOAuthConfig {
  /// Application (client) ID del App Registration — público por diseño
  /// para un cliente PKCE ("public client flow"), no hace falta guardar
  /// ningún secret. Un solo client id para Android y Windows, a
  /// diferencia de Google (que separa "Android"/"Desktop app").
  static const clientId = String.fromEnvironment('MICROSOFT_OAUTH_CLIENT_ID');

  static bool get isConfigured => clientId.isNotEmpty;
}
