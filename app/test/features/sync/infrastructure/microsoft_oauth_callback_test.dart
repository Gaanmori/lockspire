// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Lockspire

import 'package:flutter_test/flutter_test.dart';
import 'package:lockspire/features/sync/infrastructure/microsoft_oauth_auth.dart';

const _state = 'estado-aleatorio-de-este-login';

Uri _callback(Map<String, String> params, {String path = '/'}) => Uri(
  scheme: 'http',
  host: 'localhost',
  port: 5000,
  path: path,
).replace(queryParameters: params);

void main() {
  group('evaluateOAuthCallback (S9)', () {
    test('la redirección con el state correcto entrega el código', () {
      final outcome = evaluateOAuthCallback(
        _callback({'code': 'abc', 'state': _state}),
        _state,
      );
      expect(outcome, isA<OAuthCallbackCode>());
      expect((outcome as OAuthCallbackCode).code, 'abc');
    });

    test('sin state, con otro state o con otra ruta se ignora — antes se '
        'aceptaba la primera petición que llegara', () {
      for (final uri in [
        _callback({'code': 'inyectado'}),
        _callback({'code': 'inyectado', 'state': 'otro'}),
        _callback({'code': 'inyectado', 'state': '${_state}x'}),
        _callback({'code': 'abc', 'state': _state}, path: '/favicon.ico'),
        _callback({}),
      ]) {
        expect(
          evaluateOAuthCallback(uri, _state),
          isA<OAuthCallbackIgnored>(),
          reason: '$uri',
        );
      }
    });

    test('un error con el state correcto se informa a la app', () {
      final outcome = evaluateOAuthCallback(
        _callback({
          'error': 'access_denied',
          'error_description': '<script>alert(1)</script>',
          'state': _state,
        }),
        _state,
      );
      expect(outcome, isA<OAuthCallbackError>());
      // El texto va a la app (un Text de Flutter, no HTML); la página del
      // navegador es fija y nunca lo refleja.
      expect(
        (outcome as OAuthCallbackError).message,
        '<script>alert(1)</script>',
      );
    });

    test('un error sin state no puede cortar el login en curso', () {
      expect(
        evaluateOAuthCallback(_callback({'error': 'access_denied'}), _state),
        isA<OAuthCallbackIgnored>(),
      );
    });
  });

  group(
    'waitForOAuthCode — vuelta por dirección propia en Android (ADR 0022)',
    () {
      Uri app(Map<String, String> params) => Uri(
        scheme: 'com.lockspire.lockspire',
        host: 'oauth2redirect',
        queryParameters: params,
      );

      test(
        'ignora redirecciones ajenas y devuelve el código de este login',
        () async {
          final code = await waitForOAuthCode(
            Stream.fromIterable([
              app({'code': 'inyectado', 'state': 'otro'}),
              app({'code': 'inyectado'}),
              app({'code': 'bueno', 'state': _state}),
            ]),
            _state,
          );
          expect(code, 'bueno');
        },
      );

      test('un error con el state correcto se propaga', () async {
        await expectLater(
          waitForOAuthCode(
            Stream.value(
              app({
                'error': 'access_denied',
                'error_description': 'No',
                'state': _state,
              }),
            ),
            _state,
          ),
          throwsA(isA<StateError>()),
        );
      });
    },
  );
}
