// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Gabriel Ángel Montoya Rico

import 'package:flutter_test/flutter_test.dart';
import 'package:googleapis_auth/googleapis_auth.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:lockspire/features/sync/infrastructure/cloud_sign_in_adapters.dart';
import 'package:lockspire/features/sync/infrastructure/google_drive_android_auth.dart';
import 'package:lockspire/features/sync/infrastructure/google_drive_connection.dart';
import 'package:lockspire/features/sync/infrastructure/google_drive_desktop_auth.dart';
import 'package:lockspire/features/sync/infrastructure/microsoft_oauth_auth.dart';
import 'package:lockspire/features/sync/infrastructure/one_drive_connection.dart';

/// Un cliente autenticado que registra si se cerró.
class _AuthClient extends http.BaseClient implements AuthClient {
  var closed = false;

  @override
  AccessCredentials get credentials => AccessCredentials(
    AccessToken('Bearer', 'a', DateTime.utc(2099)),
    null,
    const ['drive.appdata'],
  );

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) =>
      MockClient((_) async => http.Response('', 200)).send(request);

  @override
  void close() => closed = true;
}

class _Desktop implements GoogleDriveDesktopAuth {
  final client = _AuthClient();
  @override
  Future<GoogleDriveConnection> connectInteractive() async =>
      GoogleDriveConnection(
        email: 'ana@gmail.ejemplo',
        refreshToken: 'r-g',
        httpClient: client,
      );
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Android implements GoogleDriveAndroidAuth {
  var disconnected = false;
  @override
  Future<GoogleDriveConnection> connectInteractive() async =>
      GoogleDriveConnection(
        email: 'ana@gmail.ejemplo',
        httpClient: _AuthClient(),
      );
  @override
  Future<void> disconnect() async => disconnected = true;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Microsoft implements MicrosoftOAuthAuth {
  @override
  Future<OneDriveConnection> connectInteractive() async =>
      const OneDriveConnection(
        email: 'ana@outlook.ejemplo',
        refreshToken: 'r-o',
        accessToken: 'a',
      );
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Cada plataforma detrás de `CloudSignInPort` (A12): qué se guarda de la
/// cuenta y qué hace desconectar.
void main() {
  test('Google en escritorio: guarda el refresh token y cierra el cliente '
      'de la conexión', () async {
    final auth = _Desktop();
    final signIn = GoogleDriveDesktopSignIn(auth);

    final account = await signIn.connect();
    await signIn.disconnect();

    expect(account.email, 'ana@gmail.ejemplo');
    expect(account.refreshToken, 'r-g');
    expect(auth.client.closed, isTrue);
  });

  test('Google en Android: sin refresh token (lo guarda el sistema); '
      'desconectar revoca el permiso', () async {
    final auth = _Android();
    final signIn = GoogleDriveAndroidSignIn(auth);

    final account = await signIn.connect();
    await signIn.disconnect();

    expect(account.refreshToken, isNull);
    expect(auth.disconnected, isTrue);
  });

  test('OneDrive: guarda el refresh token; desconectar no llama a '
      'Microsoft', () async {
    final signIn = OneDriveSignIn(_Microsoft());

    final account = await signIn.connect();

    expect(account.email, 'ana@outlook.ejemplo');
    expect(account.refreshToken, 'r-o');
    await expectLater(signIn.disconnect(), completes);
  });
}
