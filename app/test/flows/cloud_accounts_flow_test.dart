// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Gabriel Ángel Montoya Rico

import 'package:flutter_test/flutter_test.dart';
import 'package:lockspire/features/sync/domain/ports/active_sync_provider_port.dart';
import 'package:lockspire/features/sync/domain/ports/cloud_sign_in_port.dart';
import 'package:lockspire/features/sync/presentation/providers/active_sync_port_provider.dart';
import 'package:lockspire/features/sync/presentation/providers/cloud_sign_in_providers.dart';
import 'package:lockspire/shared/domain/app_problem.dart';

import '../support/app_robot.dart';
import '../support/fakes/sync_fakes.dart';
import '../support/test_app.dart';

const _master = 'correcto caballo batería grapa';

/// Google Drive y OneDrive con el inicio de sesión simulado detrás de
/// `CloudSignInPort` (revisión 2026-09-30, A12) y la nube en memoria.
class _Clouds {
  final googleDrive = FakeCloudSignIn(
    const CloudSignIn(email: 'ana@gmail.ejemplo', refreshToken: 'r-g'),
  );
  final oneDrive = FakeCloudSignIn(
    const CloudSignIn(email: 'ana@outlook.ejemplo', refreshToken: 'r-o'),
  );
  final googleCloud = FakeSyncPort();
  final microsoftCloud = FakeSyncPort();

  TestApp app() => TestApp(
    extraOverrides: [
      googleDriveSignInPortProvider.overrideWithValue(googleDrive),
      oneDriveSignInPortProvider.overrideWithValue(oneDrive),
      syncPortForProvider(
        SyncProviderId.googleDrive,
      ).overrideWith((ref) async => googleCloud),
      syncPortForProvider(
        SyncProviderId.oneDrive,
      ).overrideWith((ref) async => microsoftCloud),
    ],
  );
}

Future<(_Clouds, AppRobot)> _atSync(WidgetTester tester) async {
  final clouds = _Clouds();
  await clouds.app().pump(tester);
  final robot = AppRobot(tester);
  await robot.createVault(_master);
  await robot.addPassword(title: 'Banco');
  await robot.openSync();
  return (clouds, robot);
}

void main() {
  testWidgets('conectar Google Drive sube la bóveda a esa cuenta; '
      'desconectar revoca el permiso', (tester) async {
    final (clouds, robot) = await _atSync(tester);

    await robot.tapText('Google Drive');
    await robot.tapText('Conectar con Google');

    expect(find.text('Conectado como ana@gmail.ejemplo'), findsOneWidget);
    expect(clouds.googleCloud.remoteFile, isNotNull);

    await robot.tapText('Desconectar');

    expect(clouds.googleDrive.disconnected, isTrue);
    expect(find.text('Conectar con Google'), findsOneWidget);
  });

  testWidgets('pasar de Google Drive a OneDrive pide confirmar la mudanza y '
      'la bóveda pasa a la nueva nube', (tester) async {
    final (clouds, robot) = await _atSync(tester);
    await robot.tapText('Google Drive');
    await robot.tapText('Conectar con Google');

    await robot.tapText('OneDrive');
    await robot.tapText('Conectar con OneDrive');
    await robot.tapButton('Mudar');

    expect(find.text('Conectado como ana@outlook.ejemplo'), findsOneWidget);
    expect(clouds.microsoftCloud.remoteFile, isNotNull);
  });

  testWidgets('si el inicio de sesión falla, lo dice y no conecta nada', (
    tester,
  ) async {
    final (clouds, robot) = await _atSync(tester);
    clouds.oneDrive.error = const AppProblem(AppProblemCode.oauthNoCode);

    await robot.tapText('OneDrive');
    await robot.tapText('Conectar con OneDrive');

    expect(
      find.textContaining('No se pudo conectar con OneDrive'),
      findsOneWidget,
    );
    expect(find.text('Conectar con OneDrive'), findsOneWidget);
    expect(clouds.microsoftCloud.remoteFile, isNull);
  });

  testWidgets('OneDrive sin refresh token no se da por conectado', (
    tester,
  ) async {
    final (clouds, robot) = await _atSync(tester);
    clouds.oneDrive.account = const CloudSignIn(email: 'ana@outlook.ejemplo');

    await robot.tapText('OneDrive');
    await robot.tapText('Conectar con OneDrive');

    expect(
      find.textContaining('No se pudo conectar con OneDrive'),
      findsOneWidget,
    );
    expect(find.text('Conectado como ana@outlook.ejemplo'), findsNothing);
  });
}
