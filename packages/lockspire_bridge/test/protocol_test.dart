// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Lockspire

import 'dart:convert';
import 'dart:typed_data';

import 'package:lockspire_bridge/lockspire_bridge.dart';
import 'package:test/test.dart';

const _validToken = 'AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA'; // 43
const _caller = 'chrome-extension://abcdefghijklmnopabcdefghijklmnop/';

void main() {
  group('framing', () {
    test('ida y vuelta, también con frames partidos y concatenados', () {
      final a = encodeFrame({'type': 'A', 'x': 'ñandú'});
      final b = encodeFrame({'type': 'B'});
      final all = Uint8List.fromList([...a, ...b]);
      final decoder = FrameDecoder();

      final frames = <Uint8List>[];
      for (var i = 0; i < all.length; i += 3) {
        frames.addAll(
          decoder.add(all.sublist(i, i + 3 > all.length ? all.length : i + 3)),
        );
      }
      expect(frames.map(decodeFrameBody).toList(), [
        {'type': 'A', 'x': 'ñandú'},
        {'type': 'B'},
      ]);
      expect(decoder.hasPartialFrame, isFalse);
    });

    test(
      'el prefijo es uint32 little-endian (formato de Native Messaging)',
      () {
        final frame = encodeFrame({'a': 1});
        final body = utf8.encode('{"a":1}');
        expect(frame.sublist(0, 4), [body.length, 0, 0, 0]);
      },
    );

    test('rechaza un frame que anuncia más de 1 MiB sin esperar el cuerpo', () {
      final header = Uint8List(4);
      ByteData.sublistView(
        header,
      ).setUint32(0, maxFrameBytes + 1, Endian.little);
      expect(
        () => FrameDecoder().add(header),
        throwsA(isA<BridgeProtocolException>()),
      );
    });

    test('rechaza JSON que no es un objeto en la raíz', () {
      expect(
        () => decodeFrameBody(utf8.encode('[1,2]')),
        throwsA(isA<BridgeProtocolException>()),
      );
      expect(
        () => decodeFrameBody(utf8.encode('{no json')),
        throwsA(isA<BridgeProtocolException>()),
      );
    });
  });

  group('HELLO', () {
    test('acepta un HELLO del native host bien formado', () {
      final hello = HelloMessage.parse({
        'v': 1,
        'type': 'HELLO',
        'token': _validToken,
        'client': 'native-host',
        'caller': _caller,
      });
      expect(hello.client, ClientKind.nativeHost);
      expect(hello.caller, _caller);
    });

    test('rechaza caller ausente o con formato raro para el native host', () {
      for (final caller in [
        null,
        'https://evil.com/',
        'chrome-extension://ABC/',
      ]) {
        expect(
          () => HelloMessage.parse({
            'v': 1,
            'type': 'HELLO',
            'token': _validToken,
            'client': 'native-host',
            'caller': ?caller,
          }),
          throwsA(isA<BridgeProtocolException>()),
          reason: 'caller=$caller',
        );
      }
    });

    test('rechaza token mal formado, versión distinta y claves extra', () {
      Map<String, Object?> base() => {
        'v': 1,
        'type': 'HELLO',
        'token': _validToken,
        'client': 'app-instance',
      };
      expect(HelloMessage.parse(base()).client, ClientKind.appInstance);
      expect(
        () => HelloMessage.parse(base()..['token'] = 'corto'),
        throwsA(isA<BridgeProtocolException>()),
      );
      expect(
        () => HelloMessage.parse(base()..['v'] = 2),
        throwsA(isA<BridgeProtocolException>()),
      );
      expect(
        () => HelloMessage.parse(base()..['extra'] = true),
        throwsA(isA<BridgeProtocolException>()),
      );
    });
  });

  group('peticiones', () {
    test('ida y vuelta de todas las peticiones', () {
      final requests = <BridgeRequest>[
        const PingRequest('r1'),
        const GetCredentialsRequest('r2', origin: 'https://example.com'),
        const GetCredentialSecretRequest(
          'r3',
          origin: 'https://login.example.com:8443',
          entryId: '3f2c9a1e-0000-4000-8000-000000000000',
        ),
        const GeneratePasswordRequest('r4', length: 20),
        const ShowAppRequest('r5'),
        const ListCredentialsRequest('r6'),
        const RequestLinkOriginRequest(
          'r7',
          origin: 'https://www.facebook.com',
          entryId: '3f2c9a1e-0000-4000-8000-000000000000',
        ),
      ];
      for (final request in requests) {
        final parsed = BridgeRequest.parse(request.toJson());
        expect(parsed.toJson(), request.toJson());
      }
    });

    test('origin: solo lo que produce URL.origin para http/https', () {
      const valid = [
        'https://example.com',
        'http://localhost:3000',
        'https://xn--nand-lqa.com',
        'https://[::1]:8080',
      ];
      const invalid = [
        'https://example.com/',
        'https://example.com/login',
        'https://example.com?x=1',
        'https://user@example.com',
        'HTTPS://EXAMPLE.COM',
        'file:///etc/passwd',
        'chrome://settings',
        'javascript:alert(1)',
        'https://exa mple.com',
        '',
      ];
      for (final origin in valid) {
        expect(
          BridgeRequest.parse({
            'v': 1,
            'id': 'x',
            'type': 'GET_CREDENTIALS_FOR_ORIGIN',
            'origin': origin,
          }),
          isA<GetCredentialsRequest>(),
          reason: origin,
        );
      }
      for (final origin in invalid) {
        expect(
          () => BridgeRequest.parse({
            'v': 1,
            'id': 'x',
            'type': 'GET_CREDENTIALS_FOR_ORIGIN',
            'origin': origin,
          }),
          throwsA(isA<BridgeProtocolException>()),
          reason: origin,
        );
      }
    });

    test(
      'rechaza claves extra, tipos incorrectos y rangos fuera de límite',
      () {
        final bad = <Map<String, Object?>>[
          {'v': 1, 'id': 'x', 'type': 'PING', 'extra': 1},
          {'v': 1, 'id': 'x', 'type': 'PING', 'password': 'nope'},
          {'v': 2, 'id': 'x', 'type': 'PING'},
          {'v': 1, 'id': 'x y', 'type': 'PING'},
          {'v': 1, 'id': 'a' * 65, 'type': 'PING'},
          {'v': 1, 'id': 'x', 'type': 'NO_EXISTE'},
          {'v': 1, 'id': 'x', 'type': 'GENERATE_PASSWORD', 'length': 15},
          {'v': 1, 'id': 'x', 'type': 'GENERATE_PASSWORD', 'length': 65},
          {'v': 1, 'id': 'x', 'type': 'GENERATE_PASSWORD', 'length': '20'},
          {
            'v': 1,
            'id': 'x',
            'type': 'GET_CREDENTIAL_SECRET',
            'origin': 'https://a.com',
            'entry_id': '../etc',
          },
          {'v': 1, 'id': 'x', 'type': 'GET_CREDENTIALS_FOR_ORIGIN'},
          {'v': 1, 'id': 'x', 'type': 'LIST_CREDENTIALS', 'query': 'fa'},
          {
            'v': 1,
            'id': 'x',
            'type': 'REQUEST_LINK_ORIGIN',
            'origin': 'file:///x',
            'entry_id': 'e1',
          },
          {'v': 1, 'id': 'x', 'type': 'REQUEST_LINK_ORIGIN', 'entry_id': 'e1'},
        ];
        for (final json in bad) {
          expect(
            () => BridgeRequest.parse(json),
            throwsA(isA<BridgeProtocolException>()),
            reason: '$json',
          );
        }
      },
    );

    test('tryExtractId solo devuelve ids con formato válido', () {
      expect(BridgeRequest.tryExtractId({'id': 'ok-1'}), 'ok-1');
      expect(BridgeRequest.tryExtractId({'id': 'no válido'}), isNull);
      expect(BridgeRequest.tryExtractId({'id': 3}), isNull);
    });
  });

  group('respuestas', () {
    test('CREDENTIALS no incluye contraseñas', () {
      final json = credentialsResponse('r', [
        const CredentialSummary(
          entryId: 'e1',
          title: 'Ejemplo',
          username: 'ana',
        ),
      ]);
      expect(jsonEncode(json), isNot(contains('password')));
    });

    test('expectResponseEnvelope exige correlación de id', () {
      expect(
        () => expectResponseEnvelope(okResponse('otro'), requestId: 'r1'),
        throwsA(isA<BridgeProtocolException>()),
      );
      expectResponseEnvelope(okResponse('r1'), requestId: 'r1');
    });
  });
}
