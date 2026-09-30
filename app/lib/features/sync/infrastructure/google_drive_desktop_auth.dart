// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Gabriel Ángel Montoya Rico

import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;

import 'package:googleapis_auth/auth_io.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

import 'google_drive_connection.dart';
import 'google_drive_scopes.dart';
import 'package:lockspire/shared/domain/app_problem.dart';

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

  /// Cliente HTTP de base. `null` en la app: `googleapis_auth` crea el suyo
  /// y lo cierra con la conexión. Los tests pasan un servidor simulado.
  final http.Client? _baseClient;

  /// Abre la página de consentimiento de Google. Por defecto, el navegador
  /// del sistema; en los tests, el test hace de navegador.
  final Future<bool> Function(Uri) _openBrowser;

  GoogleDriveDesktopAuth(
    this._clientId, {
    this._baseClient,
    Future<bool> Function(Uri)? openBrowser,
  }) : _openBrowser = openBrowser ?? _openSystemBrowser;

  static Future<bool> _openSystemBrowser(Uri url) =>
      launchUrl(url, mode: LaunchMode.externalApplication);

  /// Conexión interactiva — abre el navegador del sistema para el
  /// consentimiento. Solo debe llamarse desde el botón "Conectar con
  /// Google", nunca desde un trigger de sync automático. Pide, además del
  /// scope de Drive, el de email — solo para mostrar qué cuenta quedó
  /// conectada en la UI (ver `google_drive_scopes.dart`).
  ///
  /// Si el navegador no abre, falla con `oauthBrowserFailed` en vez de
  /// esperar para siempre un consentimiento que nunca va a llegar
  /// (encontrado por un test, 2026-09-30).
  Future<GoogleDriveConnection> connectInteractive() async {
    final browserFailed = Completer<AutoRefreshingAuthClient>();
    final consent = clientViaUserConsent(
      _clientId,
      const [driveAppDataScope, driveUserInfoEmailScope],
      (uri) => unawaited(
        _openBrowser(Uri.parse(uri)).then((launched) {
          if (!launched && !browserFailed.isCompleted) {
            browserFailed.completeError(
              const AppProblem(AppProblemCode.oauthBrowserFailed),
            );
          }
        }),
      ),
      baseClient: _baseClient,
    );
    final client = await Future.any([consent, browserFailed.future]);
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
    ], baseClient: _baseClient);
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
      throw const AppProblem(
        AppProblemCode.accountEmailUnreadable,
        detail: 'Google',
      );
    }
    return email;
  }
}
