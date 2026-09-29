// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Gabriel Ángel Montoya Rico

import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

import 'oauth_app_redirect.dart';
import 'one_drive_connection.dart';
import 'package:lockspire/shared/domain/app_problem.dart';

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

/// Valor aleatorio para el parámetro `state` de OAuth (RFC 6749 §10.12):
/// 32 bytes, base64url sin padding.
String _generateState() => _generateCodeVerifier();

/// Qué hacer con una petición que llega al servidor loopback (hallazgo
/// S9 de la revisión 2026-09-25).
sealed class OAuthCallbackOutcome {
  const OAuthCallbackOutcome();
}

/// No es la redirección de este login (otra pestaña, otro proceso, el
/// favicon, un `state` que no coincide): se responde 400 y se sigue
/// esperando la buena.
class OAuthCallbackIgnored extends OAuthCallbackOutcome {
  const OAuthCallbackIgnored();
}

class OAuthCallbackCode extends OAuthCallbackOutcome {
  final String code;
  const OAuthCallbackCode(this.code);
}

class OAuthCallbackError extends OAuthCallbackOutcome {
  final String message;
  const OAuthCallbackError(this.message);
}

/// Solo cuenta la redirección a `/` con el [expectedState] exacto; todo lo
/// demás se ignora. Sin esto, el servidor aceptaba la **primera**
/// petición que llegara al puerto, viniera de donde viniera.
OAuthCallbackOutcome evaluateOAuthCallback(Uri uri, String expectedState) {
  if (uri.path != '/' && uri.path.isNotEmpty) {
    return const OAuthCallbackIgnored();
  }
  final params = uri.queryParameters;
  final state = params['state'];
  if (state == null || !_constantTimeEquals(state, expectedState)) {
    return const OAuthCallbackIgnored();
  }
  final code = params['code'];
  if (code != null && code.isNotEmpty) return OAuthCallbackCode(code);
  return OAuthCallbackError(
    params['error_description'] ?? params['error'] ?? '',
  );
}

/// Espera en [redirects] la vuelta de este login (dirección propia, ADR
/// 0022). Las que no traen el [expectedState] se ignoran, igual que en
/// loopback: solo la redirección de este login entrega el código.
Future<String> waitForOAuthCode(
  Stream<Uri> redirects,
  String expectedState,
) async {
  await for (final uri in redirects) {
    switch (evaluateOAuthCallback(uri, expectedState)) {
      case OAuthCallbackIgnored():
        continue;
      case OAuthCallbackCode(:final code):
        return code;
      case OAuthCallbackError(:final message):
        throw AppProblem(
          AppProblemCode.oauthNoCode,
          detail: message.isEmpty ? null : message,
        );
    }
  }
  throw const AppProblem(AppProblemCode.oauthLoginClosed);
}

bool _constantTimeEquals(String a, String b) {
  if (a.length != b.length) return false;
  var diff = 0;
  for (var i = 0; i < a.length; i++) {
    diff |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
  }
  return diff == 0;
}

/// Tiempo máximo esperando que el usuario complete el login en el
/// navegador. Sin límite, cerrar el navegador dejaba la app esperando
/// para siempre con un puerto abierto.
const _loginTimeout = Duration(minutes: 5);

/// Páginas fijas: nunca se refleja nada de la petición (antes se escribía
/// `error_description` sin escapar, hallazgo S9). El detalle del error se
/// muestra en la app.
const _successPage =
    '<!doctype html><meta charset="utf-8"><title>Lockspire</title>'
    '<p>Listo, ya puede volver a Lockspire.</p>';
const _errorPage =
    '<!doctype html><meta charset="utf-8"><title>Lockspire</title>'
    '<p>No se pudo conectar. Vuelva a Lockspire para ver el detalle.</p>';

Future<void> _respond(HttpRequest request, int status, String? html) async {
  request.response
    ..statusCode = status
    ..headers.set('Cache-Control', 'no-store')
    // Defensa en profundidad: la página no puede cargar ni ejecutar nada.
    ..headers.set('Content-Security-Policy', "default-src 'none'")
    ..headers.set('Referrer-Policy', 'no-referrer');
  if (html != null) {
    request.response
      ..headers.contentType = ContentType.html
      ..write(html);
  }
  await request.response.close();
}

/// Autenticación contra OneDrive (Microsoft identity platform) con el
/// navegador del sistema (RFC 8252). Es cliente público con PKCE, sin client
/// secret. La vuelta del navegador depende de la plataforma:
///
/// - En escritorio, loopback (`http://localhost` con puerto libre).
/// - En Android, la dirección propia `com.lockspire.lockspire://oauth2redirect`
///   (ADR 0022). El loopback fallaba en HyperOS: la app queda congelada
///   mientras el usuario está en el navegador y nadie atiende la redirección.
class MicrosoftOAuthAuth {
  final String _clientId;
  final http.Client _http;

  /// Si se indica, el navegador vuelve a la app por esta dirección propia en
  /// vez de por loopback (Android, ADR 0022). Si no, loopback (escritorio).
  final OAuthAppRedirect? _appRedirect;

  MicrosoftOAuthAuth(
    this._clientId, {
    http.Client? httpClient,
    OAuthAppRedirect? appRedirect,
  }) : _http = httpClient ?? http.Client(),
       // ignore: prefer_initializing_formals, parámetro público sin guion bajo
       _appRedirect = appRedirect;

  /// Conexión interactiva — abre el navegador del sistema para el
  /// consentimiento. Solo debe llamarse desde el botón "Conectar con
  /// OneDrive", nunca desde un trigger de sync automático.
  Future<OneDriveConnection> connectInteractive() async {
    final verifier = _generateCodeVerifier();
    final challenge = codeChallengeFromVerifier(verifier);
    final state = _generateState();

    final appRedirect = _appRedirect;
    final server = appRedirect == null
        ? await HttpServer.bind(InternetAddress.loopbackIPv4, 0)
        : null;
    try {
      final redirectUri =
          appRedirect?.redirectUri ?? 'http://localhost:${server!.port}';
      // Escuchar antes de abrir el navegador: la vuelta puede ser rápida.
      final codeFuture = appRedirect != null
          ? waitForOAuthCode(appRedirect.redirects, state)
          : _awaitAuthorizationCode(server!, state);
      final authorizeUri = Uri.parse(_authorizeEndpoint).replace(
        queryParameters: {
          'client_id': _clientId,
          'response_type': 'code',
          'redirect_uri': redirectUri,
          'scope': _scopes,
          'code_challenge': challenge,
          'code_challenge_method': 'S256',
          'state': state,
        },
      );

      final launched = await launchUrl(
        authorizeUri,
        mode: LaunchMode.externalApplication,
      );
      if (!launched) {
        throw const AppProblem(AppProblemCode.oauthBrowserFailed);
      }

      final code = await codeFuture.timeout(
        _loginTimeout,
        onTimeout: () => throw const AppProblem(
          AppProblemCode.oauthTimedOut,
          detail: 'Microsoft',
        ),
      );

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
      await server?.close(force: true);
    }
  }

  /// Atiende peticiones hasta que llega la redirección de este login
  /// ([evaluateOAuthCallback]); las demás reciben un 400 y se ignoran.
  Future<String> _awaitAuthorizationCode(
    HttpServer server,
    String expectedState,
  ) async {
    await for (final request in server) {
      switch (evaluateOAuthCallback(request.uri, expectedState)) {
        case OAuthCallbackIgnored():
          await _respond(request, HttpStatus.badRequest, null);
        case OAuthCallbackCode(:final code):
          await _respond(request, HttpStatus.ok, _successPage);
          return code;
        case OAuthCallbackError(:final message):
          await _respond(request, HttpStatus.ok, _errorPage);
          throw StateError(message);
      }
    }
    throw const AppProblem(AppProblemCode.oauthLoginClosed);
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
      throw AppProblem(
        AppProblemCode.oauthRefreshFailed,
        detail: '${body['error_description'] ?? body['error']}',
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
      throw AppProblem(
        AppProblemCode.oauthTokenFailed,
        detail: '${body['error_description'] ?? body['error']}',
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
      throw const AppProblem(
        AppProblemCode.accountEmailUnreadable,
        detail: 'Microsoft',
      );
    }
    return email;
  }
}
