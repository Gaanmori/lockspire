// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Gabriel Ángel Montoya Rico

import 'dart:convert';
import 'dart:io' show Platform;

import 'package:googleapis_auth/auth_io.dart';
import 'package:url_launcher/url_launcher.dart';

import 'google_drive_connection.dart';
import 'google_drive_scopes.dart';

/// Autenticación contra Google Drive en escritorio (Windows y Linux).
///
/// No hay soporte first-party de `google_sign_in` para Windows (issue
/// abierto `flutter/flutter#184242`) ni para Linux — se usa el flujo
/// "Desktop app" con
/// loopback que documenta Google (no deprecado para desktop, solo para
/// apps nativas móviles), vía las primitivas de `googleapis_auth`
/// (`clientViaUserConsent` administra el `HttpServer` local y el
/// intercambio de código por tokens solo). A diferencia de Android, acá
/// sí hace falta guardar el refresh token — no hay sesión nativa del SO
/// que la sostenga entre corridas de la app.
/// `true` en las plataformas que usan [GoogleDriveDesktopAuth] en vez del
/// flujo nativo de `google_sign_in` (Android).
bool get usesDesktopGoogleAuth => Platform.isWindows || Platform.isLinux;

class GoogleDriveDesktopAuth {
  final ClientId _clientId;

  GoogleDriveDesktopAuth(this._clientId);

  /// Conexión interactiva — abre el navegador del sistema para el
  /// consentimiento. Solo debe llamarse desde el botón "Conectar con
  /// Google", nunca desde un trigger de sync automático. Pide, además del
  /// scope de Drive, el de email — solo para mostrar qué cuenta quedó
  /// conectada en la UI (ver `google_drive_scopes.dart`).
  Future<GoogleDriveConnection> connectInteractive() async {
    final client = await clientViaUserConsent(
      _clientId,
      const [driveAppDataScope, driveUserInfoEmailScope],
      (uri) => launchUrl(Uri.parse(uri), mode: LaunchMode.externalApplication),
    );
    final email = await _fetchEmail(client);
    return GoogleDriveConnection(
      email: email,
      refreshToken: client.credentials.refreshToken,
      httpClient: client,
    );
  }

  /// Reconexión sin interacción, a partir del refresh token guardado —
  /// usada por `activeSyncPortProvider` en cada sync. El email ya se
  /// conoce de la conexión inicial (`GoogleDriveAccountPort`), no hace
  /// falta volver a pedirlo.
  Future<GoogleDriveConnection> reconnect({
    required String refreshToken,
    required String email,
  }) async {
    final client = await clientViaRefreshToken(_clientId, refreshToken, const [
      driveAppDataScope,
    ]);
    return GoogleDriveConnection(
      email: email,
      refreshToken: refreshToken,
      httpClient: client,
    );
  }

  Future<String> _fetchEmail(AutoRefreshingAuthClient client) async {
    final response = await client.get(
      Uri.parse('https://www.googleapis.com/oauth2/v3/userinfo'),
    );
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final email = body['email'] as String?;
    if (email == null) {
      throw StateError('No se pudo leer el email de la cuenta de Google');
    }
    return email;
  }
}
