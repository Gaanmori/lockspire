// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Gabriel Ángel Montoya Rico

import 'package:extension_google_sign_in_as_googleapis_auth/extension_google_sign_in_as_googleapis_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:google_sign_in_platform_interface/google_sign_in_platform_interface.dart';

import 'google_drive_connection.dart';
import 'google_drive_scopes.dart';
import 'google_oauth_config.dart';

const _scopes = [driveAppDataScope];

/// Autenticación contra Google Drive en Android, vía `google_sign_in`
/// (API v7 — separa autenticación de la autorización de scopes, ver
/// docs/STATE.md Fase 8). No guarda tokens propios: la sesión la
/// administra el SDK nativo (Credential Manager/Play Services), acá solo
/// se pide un cliente autenticado fresco cada vez que hace falta.
class GoogleDriveAndroidAuth {
  Future<void>? _initFuture;

  /// `serverClientId` es obligatorio en Android — Credential Manager lo
  /// exige aunque no haya backend propio (confirmado en runtime:
  /// `GoogleSignInException(clientConfigurationError, "serverClientId
  /// must be provided on Android")` sin él). Ver
  /// `GoogleOAuthConfig.androidServerClientId`.
  Future<void> _ensureInitialized() {
    return _initFuture ??= GoogleSignIn.instance.initialize(
      serverClientId: GoogleOAuthConfig.androidServerClientId,
    );
  }

  /// Conexión interactiva — muestra el selector de cuentas nativo. Solo
  /// debe llamarse desde una acción directa del usuario (botón "Conectar
  /// con Google"), nunca desde un trigger de sync automático.
  Future<GoogleDriveConnection> connectInteractive() async {
    await _ensureInitialized();
    final account = await GoogleSignIn.instance.authenticate();
    final authorization = await account.authorizationClient.authorizeScopes(
      _scopes,
    );
    return GoogleDriveConnection(
      email: account.email,
      httpClient: authorization.authClient(scopes: _scopes),
    );
  }

  /// Reconexión silenciosa — usada por `activeSyncPortProvider` en cada
  /// sync. Devuelve `null` si no hay sesión previa o quedó revocada; en
  /// ese caso hace falta `connectInteractive()` de nuevo (el usuario lo
  /// dispara desde `SyncSettingsScreen`).
  ///
  /// Primero pide el token directamente a la API de autorización de
  /// Android para la cuenta [email] ya conectada: si el permiso de Drive
  /// sigue dado, lo entrega **sin mostrar nada**. La hoja "Iniciando
  /// sesión" sale del paso de *autenticación* (Credential Manager), que
  /// aquí solo se usa como respaldo si lo anterior no alcanza. Antes se
  /// autenticaba siempre, y como cada operación arma la conexión con un
  /// token fresco, la hoja aparecía en cada sync.
  Future<GoogleDriveConnection?> reconnectSilently({String? email}) async {
    if (email != null && email.isNotEmpty) {
      final silent = await authorizeWithoutUi(email: email);
      if (silent != null) return silent;
    }
    await _ensureInitialized();
    final account = await GoogleSignIn.instance
        .attemptLightweightAuthentication();
    if (account == null) return null;
    final authorization = await account.authorizationClient
        .authorizationForScopes(_scopes);
    if (authorization == null) return null;
    return GoogleDriveConnection(
      email: account.email,
      httpClient: authorization.authClient(scopes: _scopes),
    );
  }

  /// Solo la API de autorización, **nunca** la hoja de autenticación: el
  /// token si el permiso de Drive para [email] sigue dado, o `null`. Es lo
  /// que usa la consulta previa al desbloqueo (ADR 0024), donde no puede
  /// aparecer ninguna ventana encima de la pantalla de bloqueo.
  Future<GoogleDriveConnection?> authorizeWithoutUi({
    required String email,
  }) async {
    await _ensureInitialized();
    final tokens = await GoogleSignInPlatform.instance
        .clientAuthorizationTokensForScopes(
          ClientAuthorizationTokensForScopesParameters(
            request: AuthorizationRequestDetails(
              scopes: _scopes,
              userId: null,
              email: email,
              promptIfUnauthorized: false,
            ),
          ),
        );
    if (tokens == null) return null;
    return GoogleDriveConnection(
      email: email,
      httpClient: GoogleSignInClientAuthorization(
        accessToken: tokens.accessToken,
      ).authClient(scopes: _scopes),
    );
  }

  Future<void> disconnect() async {
    await _ensureInitialized();
    await GoogleSignIn.instance.disconnect();
  }
}
