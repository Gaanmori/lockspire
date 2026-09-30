// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Gabriel Ángel Montoya Rico

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:googleapis_auth/auth_io.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:lockspire/features/sync/infrastructure/google_drive_desktop_auth.dart';
import 'package:lockspire/features/sync/infrastructure/google_drive_scopes.dart';
import 'package:lockspire/shared/domain/app_problem.dart';

/// El servidor de tokens de Google y el endpoint del correo, en memoria.
class _FakeGoogle {
  final tokenRequests = <Map<String, String>>[];
  Map<String, Object?> userInfo = {'email': 'ana@gmail.ejemplo'};

  late final client = MockClient((request) async {
    final json = {'content-type': 'application/json'};
    if (request.url.toString() == 'https://oauth2.googleapis.com/token') {
      tokenRequests.add(Uri.splitQueryString(request.body));
      return http.Response(
        jsonEncode({
          'access_token': 'access-1',
          'token_type': 'Bearer',
          'expires_in': 3600,
          'refresh_token': 'refresh-1',
          'scope': '$driveAppDataScope $driveUserInfoEmailScope',
        }),
        200,
        headers: json,
      );
    }
    if (request.url.path == '/oauth2/v3/userinfo') {
      expect(request.headers['Authorization'], 'Bearer access-1');
      return http.Response(jsonEncode(userInfo), 200, headers: json);
    }
    return http.Response('', 404);
  });
}

/// Hace de navegador: tras el "consentimiento" vuelve al servidor local
/// con el código y el `state` recibidos.
Future<bool> _consentingBrowser(Uri url) async {
  final back = Uri.parse(url.queryParameters['redirect_uri']!).replace(
    queryParameters: {'code': 'code-1', 'state': url.queryParameters['state']!},
  );
  unawaited(() async {
    final response = await (await HttpClient().getUrl(back)).close();
    await response.drain<void>();
  }());
  return true;
}

/// Google Drive en Windows y Linux: consentimiento en el navegador con
/// vuelta a un servidor local (loopback) y refresh token propio.
void main() {
  late _FakeGoogle google;
  final clientId = ClientId('client-1.apps.googleusercontent.com', 'secreto');

  setUp(() => google = _FakeGoogle());

  test('pide solo Drive (carpeta de la app) y el correo, y guarda el '
      'refresh token', () async {
    Uri? consentPage;
    final auth = GoogleDriveDesktopAuth(
      clientId,
      baseClient: google.client,
      openBrowser: (url) {
        consentPage = url;
        return _consentingBrowser(url);
      },
    );

    final connection = await auth.connectInteractive();

    expect(connection.email, 'ana@gmail.ejemplo');
    expect(connection.refreshToken, 'refresh-1');
    final query = consentPage!.queryParameters;
    expect(query['scope']!.split(' '), {
      driveAppDataScope,
      driveUserInfoEmailScope,
    });
    expect(query['redirect_uri'], startsWith('http://localhost:'));
    expect(query['code_challenge_method'], 'S256');
    expect(google.tokenRequests.single['code'], 'code-1');
  });

  test('una cuenta sin correo legible no se conecta', () async {
    google.userInfo = {};
    final auth = GoogleDriveDesktopAuth(
      clientId,
      baseClient: google.client,
      openBrowser: _consentingBrowser,
    );

    await expectLater(
      auth.connectInteractive(),
      throwsA(
        isA<AppProblem>().having(
          (e) => e.code,
          'code',
          AppProblemCode.accountEmailUnreadable,
        ),
      ),
    );
  });

  test('si el navegador no abre, lo dice en vez de esperar para '
      'siempre', () async {
    final auth = GoogleDriveDesktopAuth(
      clientId,
      baseClient: google.client,
      openBrowser: (_) async => false,
    );

    await expectLater(
      auth.connectInteractive().timeout(const Duration(seconds: 5)),
      throwsA(
        isA<AppProblem>().having(
          (e) => e.code,
          'code',
          AppProblemCode.oauthBrowserFailed,
        ),
      ),
    );
  });

  test('reconectar usa el refresh token guardado, sin navegador', () async {
    final auth = GoogleDriveDesktopAuth(
      clientId,
      baseClient: google.client,
      openBrowser: (_) => fail('no debe abrir el navegador'),
    );

    final connection = await auth.reconnect(
      refreshToken: 'refresh-guardado',
      email: 'ana@gmail.ejemplo',
    );

    expect(google.tokenRequests.single['grant_type'], 'refresh_token');
    expect(google.tokenRequests.single['refresh_token'], 'refresh-guardado');
    expect(connection.email, 'ana@gmail.ejemplo');
    expect(connection.refreshToken, 'refresh-guardado');
  });
}
