// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Lockspire

import 'package:extension_google_sign_in_as_googleapis_auth/extension_google_sign_in_as_googleapis_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

import 'google_drive_connection.dart';
import 'google_drive_scopes.dart';

const _scopes = [driveAppDataScope];

/// Autenticación contra Google Drive en Android, vía `google_sign_in`
/// (API v7 — separa autenticación de la autorización de scopes, ver
/// docs/STATE.md Fase 8). No guarda tokens propios: la sesión la
/// administra el SDK nativo (Credential Manager/Play Services), acá solo
/// se pide un cliente autenticado fresco cada vez que hace falta.
class GoogleDriveAndroidAuth {
  Future<void>? _initFuture;

  Future<void> _ensureInitialized() {
    return _initFuture ??= GoogleSignIn.instance.initialize();
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
  Future<GoogleDriveConnection?> reconnectSilently() async {
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

  Future<void> disconnect() async {
    await _ensureInitialized();
    await GoogleSignIn.instance.disconnect();
  }
}
