// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Lockspire

import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

import 'one_drive_connection.dart';

const _authorizeEndpoint =
    'https://login.microsoftonline.com/common/oauth2/v2.0/authorize';
const _tokenEndpoint =
    'https://login.microsoftonline.com/common/oauth2/v2.0/token';
const _meEndpoint = 'https://graph.microsoft.com/v1.0/me';
const _scopes = 'Files.ReadWrite.AppFolder User.Read offline_access';

/// Genera el par verifier/challenge de PKCE (RFC 7636) — [_codeChallenge]
/// está separado como función pura, testeable en aislamiento contra el
/// vector conocido de la RFC sin necesitar red (ver
/// `microsoft_oauth_auth_pkce_test.dart`).
String _generateCodeVerifier() {
  final random = Random.secure();
  final bytes = List<int>.generate(32, (_) => random.nextInt(256));
  return base64Url.encode(bytes).replaceAll('=', '');
}

/// `BASE64URL-ENCODE(SHA256(ASCII(code_verifier)))`, sin padding — RFC
/// 7636 §4.2.
String codeChallengeFromVerifier(String verifier) {
  final hash = sha256.convert(ascii.encode(verifier));
  return base64Url.encode(hash.bytes).replaceAll('=', '');
}

/// Autenticación contra OneDrive (Microsoft identity platform) — unificada
/// para Android y Windows, a diferencia del split de Google Drive
/// (`google_drive_android_auth.dart`/`google_drive_windows_auth.dart`):
/// Microsoft no tiene SDK first-party de Flutter en ninguna plataforma, y
/// su propia documentación recomienda el patrón loopback (`http://localhost`,
/// sin puerto fijo) + navegador del sistema para apps que usan el
/// navegador del sistema, sin distinguir plataforma (alineado con RFC
/// 8252). Cliente público con PKCE — sin client secret.
class MicrosoftOAuthAuth {
  final String _clientId;
  final http.Client _http;

  MicrosoftOAuthAuth(this._clientId, {http.Client? httpClient})
    : _http = httpClient ?? http.Client();

  /// Conexión interactiva — abre el navegador del sistema para el
  /// consentimiento. Solo debe llamarse desde el botón "Conectar con
  /// OneDrive", nunca desde un trigger de sync automático.
  Future<OneDriveConnection> connectInteractive() async {
    final verifier = _generateCodeVerifier();
    final challenge = codeChallengeFromVerifier(verifier);

    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    try {
      final redirectUri = 'http://localhost:${server.port}';
      final authorizeUri = Uri.parse(_authorizeEndpoint).replace(
        queryParameters: {
          'client_id': _clientId,
          'response_type': 'code',
          'redirect_uri': redirectUri,
          'scope': _scopes,
          'code_challenge': challenge,
          'code_challenge_method': 'S256',
        },
      );

      final launched = await launchUrl(
        authorizeUri,
        mode: LaunchMode.externalApplication,
      );
      if (!launched) {
        throw StateError('No se pudo abrir el navegador del sistema');
      }

      final request = await server.first;
      final code = request.uri.queryParameters['code'];
      final error = request.uri.queryParameters['error_description'];
      request.response
        ..statusCode = 200
        ..headers.contentType = ContentType.html
        ..write(
          error == null
              ? '<html><body>Listo, ya podés volver a Lockspire.</body></html>'
              : '<html><body>Ocurrió un error: $error</body></html>',
        );
      await request.response.close();

      if (code == null) {
        throw StateError(error ?? 'No se recibió el código de autorización');
      }

      final tokens = await _exchangeCode(
        code: code,
        verifier: verifier,
        redirectUri: redirectUri,
      );
      final email = await _fetchEmail(tokens['access_token'] as String);
      return OneDriveConnection(
        email: email,
        refreshToken: tokens['refresh_token'] as String,
        accessToken: tokens['access_token'] as String,
      );
    } finally {
      await server.close(force: true);
    }
  }

  /// Reconexión sin interacción, a partir del refresh token guardado —
  /// usada por `activeSyncPortProvider` en cada sync. Microsoft **rota el
  /// refresh token en cada uso** para clientes públicos/PKCE (a diferencia
  /// de Google) — el que devuelve [OneDriveConnection.refreshToken] acá
  /// puede ser distinto al que se pasó, y quien llama es responsable de
  /// volver a guardarlo (ver `active_sync_port_provider.dart`).
  Future<OneDriveConnection> reconnect({
    required String refreshToken,
    required String email,
  }) async {
    final response = await _http.post(
      Uri.parse(_tokenEndpoint),
      headers: const {'Content-Type': 'application/x-www-form-urlencoded'},
      body: {
        'client_id': _clientId,
        'grant_type': 'refresh_token',
        'refresh_token': refreshToken,
        'scope': _scopes,
      },
    );
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode != 200) {
      throw StateError(
        'No se pudo renovar la sesión de OneDrive: '
        '${body['error_description'] ?? body['error']}',
      );
    }
    return OneDriveConnection(
      email: email,
      refreshToken: body['refresh_token'] as String,
      accessToken: body['access_token'] as String,
    );
  }

  Future<Map<String, dynamic>> _exchangeCode({
    required String code,
    required String verifier,
    required String redirectUri,
  }) async {
    final response = await _http.post(
      Uri.parse(_tokenEndpoint),
      headers: const {'Content-Type': 'application/x-www-form-urlencoded'},
      body: {
        'client_id': _clientId,
        'grant_type': 'authorization_code',
        'code': code,
        'redirect_uri': redirectUri,
        'code_verifier': verifier,
        'scope': _scopes,
      },
    );
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode != 200) {
      throw StateError(
        'No se pudo obtener el token de OneDrive: '
        '${body['error_description'] ?? body['error']}',
      );
    }
    return body;
  }

  Future<String> _fetchEmail(String accessToken) async {
    final response = await _http.get(
      Uri.parse(_meEndpoint),
      headers: {'Authorization': 'Bearer $accessToken'},
    );
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final email = (body['mail'] ?? body['userPrincipalName']) as String?;
    if (email == null) {
      throw StateError('No se pudo leer el email de la cuenta de Microsoft');
    }
    return email;
  }
}
