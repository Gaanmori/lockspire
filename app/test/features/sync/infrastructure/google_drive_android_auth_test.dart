// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Gabriel Ángel Montoya Rico

import 'package:flutter_test/flutter_test.dart';
import 'package:google_sign_in_platform_interface/google_sign_in_platform_interface.dart';
import 'package:lockspire/features/sync/infrastructure/google_drive_android_auth.dart';
import 'package:lockspire/features/sync/infrastructure/google_drive_scopes.dart';

const _ana = GoogleSignInUserData(email: 'ana@gmail.ejemplo', id: 'ana-1');

/// El inicio de sesión nativo de Android (Credential Manager y la API de
/// autorización), simulado por debajo de `google_sign_in`.
class _FakeAndroidGoogle extends GoogleSignInPlatform {
  /// Cuentas con el permiso de Drive dado.
  final granted = <String>{};

  /// La cuenta que devuelve el inicio de sesión "liviano" (la hoja
  /// "Iniciando sesión"), o `null` si no hay sesión previa.
  GoogleSignInUserData? lightweightUser;

  final authorizationRequests = <AuthorizationRequestDetails>[];
  var sheetsShown = 0;
  var disconnected = false;
  InitParameters? initParameters;

  @override
  Future<void> init(InitParameters params) async => initParameters = params;

  @override
  bool supportsAuthenticate() => true;

  @override
  bool authorizationRequiresUserInteraction() => false;

  @override
  Future<AuthenticationResults> authenticate(
    AuthenticateParameters params,
  ) async {
    sheetsShown++;
    return _results(_ana);
  }

  @override
  Future<AuthenticationResults?> attemptLightweightAuthentication(
    AttemptLightweightAuthenticationParameters params,
  ) async {
    sheetsShown++;
    final user = lightweightUser;
    return user == null ? null : _results(user);
  }

  static AuthenticationResults _results(GoogleSignInUserData user) =>
      AuthenticationResults(
        user: user,
        authenticationTokens: const AuthenticationTokenData(idToken: 'id'),
      );

  @override
  Future<ClientAuthorizationTokenData?> clientAuthorizationTokensForScopes(
    ClientAuthorizationTokensForScopesParameters params,
  ) async {
    final request = params.request;
    authorizationRequests.add(request);
    final email = request.email ?? '';
    if (request.promptIfUnauthorized) granted.add(email);
    return granted.contains(email)
        ? const ClientAuthorizationTokenData(accessToken: 'access-1')
        : null;
  }

  @override
  Future<ServerAuthorizationTokenData?> serverAuthorizationTokensForScopes(
    ServerAuthorizationTokensForScopesParameters params,
  ) async => null;

  @override
  Future<void> signOut(SignOutParams params) async {}

  @override
  Future<void> disconnect(DisconnectParams params) async {
    disconnected = true;
    granted.clear();
  }
}

/// Google Drive en Android (Fase 8): nunca debe aparecer una ventana de
/// Google en una sincronización automática si el permiso sigue dado.
void main() {
  late _FakeAndroidGoogle google;
  late GoogleDriveAndroidAuth auth;

  setUp(() {
    google = GoogleSignInPlatform.instance = _FakeAndroidGoogle();
    auth = GoogleDriveAndroidAuth();
  });

  test('conectar muestra el selector y pide solo la carpeta de la app en '
      'Drive', () async {
    final connection = await auth.connectInteractive();

    expect(connection.email, 'ana@gmail.ejemplo');
    expect(connection.refreshToken, isNull, reason: 'la sesión es del SO');
    expect(google.initParameters, isNotNull);
    expect(google.sheetsShown, 1);
    expect(google.authorizationRequests.single.scopes, [driveAppDataScope]);
    expect(google.authorizationRequests.single.promptIfUnauthorized, isTrue);
  });

  test('con el permiso dado, reconectar no muestra nada', () async {
    google.granted.add('ana@gmail.ejemplo');

    final connection = await auth.reconnectSilently(email: 'ana@gmail.ejemplo');

    expect(connection!.email, 'ana@gmail.ejemplo');
    expect(google.sheetsShown, 0);
    expect(google.authorizationRequests.single.promptIfUnauthorized, isFalse);
  });

  test('si el permiso ya no está, prueba la sesión previa; sin ella hay que '
      'conectar de nuevo', () async {
    expect(await auth.reconnectSilently(email: 'ana@gmail.ejemplo'), isNull);
    expect(google.sheetsShown, 1);

    google.lightweightUser = _ana;
    expect(await auth.reconnectSilently(), isNull, reason: 'sin permiso');

    google.granted.add('ana@gmail.ejemplo');
    final connection = await auth.reconnectSilently();
    expect(connection!.email, 'ana@gmail.ejemplo');
  });

  test('la consulta previa al desbloqueo nunca pide nada en pantalla '
      '(ADR 0024)', () async {
    expect(await auth.authorizeWithoutUi(email: 'ana@gmail.ejemplo'), isNull);

    google.granted.add('ana@gmail.ejemplo');
    final connection = await auth.authorizeWithoutUi(
      email: 'ana@gmail.ejemplo',
    );

    expect(connection!.email, 'ana@gmail.ejemplo');
    expect(
      google.authorizationRequests.map((r) => r.promptIfUnauthorized),
      everyElement(isFalse),
    );
    expect(google.sheetsShown, 0);
  });

  test('desconectar revoca el permiso de Drive', () async {
    await auth.connectInteractive();

    await auth.disconnect();

    expect(google.disconnected, isTrue);
    expect(await auth.authorizeWithoutUi(email: 'ana@gmail.ejemplo'), isNull);
  });
}
