// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Gabriel Ángel Montoya Rico

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:lockspire/features/sync/infrastructure/microsoft_oauth_auth.dart';
import 'package:lockspire/features/sync/infrastructure/oauth_app_redirect.dart';
import 'package:lockspire/shared/domain/app_problem.dart';

/// Microsoft identity platform y Graph en memoria: canje de código,
/// renovación y el correo de la cuenta.
class _FakeMicrosoft {
  String? lastCodeVerifier;
  Map<String, String>? lastTokenRequest;
  int tokenStatus = 200;
  Map<String, Object?> me = {'mail': 'ana@outlook.ejemplo'};

  late final client = MockClient((request) async {
    final json = {'content-type': 'application/json'};
    if (request.url.path.endsWith('/oauth2/v2.0/token')) {
      final form = Uri.splitQueryString(request.body);
      lastTokenRequest = form;
      lastCodeVerifier = form['code_verifier'];
      if (tokenStatus != 200) {
        return http.Response(
          jsonEncode({
            'error': 'invalid_grant',
            'error_description': 'El código venció',
          }),
          tokenStatus,
          headers: json,
        );
      }
      return http.Response(
        jsonEncode({'access_token': 'access-2', 'refresh_token': 'refresh-2'}),
        200,
        headers: json,
      );
    }
    if (request.url.toString() == 'https://graph.microsoft.com/v1.0/me') {
      expect(request.headers['Authorization'], 'Bearer access-2');
      return http.Response(jsonEncode(me), 200, headers: json);
    }
    return http.Response('', 404);
  });
}

/// Un navegador de mentira: recibe la dirección de inicio de sesión y
/// vuelve al servidor local como lo haría Microsoft tras el consentimiento.
class _Browser {
  Uri? opened;
  HttpClientResponse? callbackResponse;

  /// Qué agrega Microsoft a la vuelta (sin el `state`, que se copia).
  Map<String, String> answer = {'code': 'code-1'};

  Future<bool> open(Uri url) async {
    opened = url;
    final redirect = Uri.parse(url.queryParameters['redirect_uri']!);
    final back = redirect.replace(
      queryParameters: {...answer, 'state': url.queryParameters['state']!},
    );
    unawaited(() async {
      final request = await HttpClient().getUrl(back);
      callbackResponse = await request.close();
      await callbackResponse!.drain<void>();
    }());
    return true;
  }
}

void main() {
  late _FakeMicrosoft microsoft;
  late _Browser browser;
  late MicrosoftOAuthAuth auth;

  setUp(() {
    microsoft = _FakeMicrosoft();
    browser = _Browser();
    auth = MicrosoftOAuthAuth(
      'client-1',
      httpClient: microsoft.client,
      openBrowser: browser.open,
    );
  });

  group('Inicio de sesión en escritorio (loopback, RFC 8252)', () {
    test(
      'pide consentimiento con PKCE y devuelve la cuenta conectada',
      () async {
        final connection = await auth.connectInteractive();

        expect(connection.email, 'ana@outlook.ejemplo');
        expect(connection.accessToken, 'access-2');
        expect(connection.refreshToken, 'refresh-2');

        final query = browser.opened!.queryParameters;
        expect(query['client_id'], 'client-1');
        expect(query['response_type'], 'code');
        expect(query['code_challenge_method'], 'S256');
        expect(query['scope'], contains('Files.ReadWrite.AppFolder'));
        expect(query['redirect_uri'], startsWith('http://localhost:'));
        // PKCE: el verificador que se manda al canjear corresponde al desafío.
        expect(
          codeChallengeFromVerifier(microsoft.lastCodeVerifier!),
          query['code_challenge'],
        );
        expect(microsoft.lastTokenRequest!['code'], 'code-1');
        expect(microsoft.lastTokenRequest!['grant_type'], 'authorization_code');
        // La página que ve el usuario no guarda nada ni se puede incrustar.
        expect(browser.callbackResponse!.statusCode, 200);
        expect(
          browser.callbackResponse!.headers.value('content-security-policy'),
          "default-src 'none'",
        );
      },
    );

    test(
      'si el usuario rechaza el permiso, el error llega traducible',
      () async {
        browser.answer = {
          'error': 'access_denied',
          'error_description': 'El usuario canceló',
        };

        await expectLater(
          auth.connectInteractive(),
          throwsA(
            isA<AppProblem>()
                .having((e) => e.code, 'code', AppProblemCode.oauthNoCode)
                .having((e) => e.detail, 'detail', 'El usuario canceló'),
          ),
        );
      },
    );

    test('si no se puede abrir el navegador, lo dice', () async {
      auth = MicrosoftOAuthAuth(
        'client-1',
        httpClient: microsoft.client,
        openBrowser: (_) async => false,
      );

      await expectLater(
        auth.connectInteractive(),
        throwsA(
          isA<AppProblem>().having(
            (e) => e.code,
            'code',
            AppProblemCode.oauthBrowserFailed,
          ),
        ),
      );
    });

    test('si Microsoft no canjea el código, lo dice con su motivo', () async {
      microsoft.tokenStatus = 400;

      await expectLater(
        auth.connectInteractive(),
        throwsA(
          isA<AppProblem>()
              .having((e) => e.code, 'code', AppProblemCode.oauthTokenFailed)
              .having((e) => e.detail, 'detail', 'El código venció'),
        ),
      );
    });

    test('una cuenta sin correo legible no se conecta', () async {
      microsoft.me = {'displayName': 'Ana'};

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

    test('userPrincipalName sirve de correo si no hay "mail"', () async {
      microsoft.me = {'userPrincipalName': 'ana@empresa.ejemplo'};

      final connection = await auth.connectInteractive();

      expect(connection.email, 'ana@empresa.ejemplo');
    });
  });

  test(
    'en Android vuelve por la dirección propia de la app (ADR 0022)',
    () async {
      final redirect = _FakeAppRedirect();
      auth = MicrosoftOAuthAuth(
        'client-1',
        httpClient: microsoft.client,
        appRedirect: redirect,
        openBrowser: (url) async {
          expect(
            url.queryParameters['redirect_uri'],
            'com.lockspire.lockspire://oauth2redirect',
          );
          redirect.arrive(
            Uri.parse(redirect.redirectUri).replace(
              queryParameters: {
                'code': 'code-1',
                'state': url.queryParameters['state']!,
              },
            ),
          );
          return true;
        },
      );

      final connection = await auth.connectInteractive();

      expect(connection.email, 'ana@outlook.ejemplo');
    },
  );

  group('Renovar la sesión', () {
    test(
      'devuelve el token de acceso nuevo y el refresh token rotado',
      () async {
        final connection = await auth.reconnect(
          refreshToken: 'refresh-1',
          email: 'ana@outlook.ejemplo',
        );

        expect(microsoft.lastTokenRequest!['grant_type'], 'refresh_token');
        expect(microsoft.lastTokenRequest!['refresh_token'], 'refresh-1');
        expect(connection.refreshToken, 'refresh-2');
        expect(connection.accessToken, 'access-2');
      },
    );

    test('si Microsoft la rechaza, lo dice con su motivo', () async {
      microsoft.tokenStatus = 400;

      await expectLater(
        auth.reconnect(refreshToken: 'viejo', email: 'ana@outlook.ejemplo'),
        throwsA(
          isA<AppProblem>()
              .having((e) => e.code, 'code', AppProblemCode.oauthRefreshFailed)
              .having((e) => e.detail, 'detail', 'El código venció'),
        ),
      );
    });
  });
}

class _FakeAppRedirect implements OAuthAppRedirect {
  final _controller = StreamController<Uri>.broadcast();

  void arrive(Uri uri) => scheduleMicrotask(() => _controller.add(uri));

  @override
  String get redirectUri => 'com.lockspire.lockspire://oauth2redirect';

  @override
  Stream<Uri> get redirects => _controller.stream;
}
