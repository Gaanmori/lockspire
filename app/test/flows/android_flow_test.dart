// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Gabriel Ángel Montoya Rico

import 'package:flutter_test/flutter_test.dart';
import 'package:lockspire/features/appearance/domain/appearance_preference.dart';

import '../support/app_robot.dart';
import '../support/test_app.dart';

Future<(TestApp, AppRobot)> _androidUnlocked(WidgetTester tester) async {
  final app = TestApp(android: true);
  await app.pump(tester);
  final robot = AppRobot(tester);
  await robot.createVault('correcto caballo batería grapa');
  return (app, robot);
}

/// Lo propio de Android: el servicio de autocompletado del sistema y el
/// ícono del lanzador según el tema.
void main() {
  testWidgets('Ajustes → Integraciones → Autocompletado lleva a los ajustes '
      'del sistema para activar Lockspire', (tester) async {
    final (app, robot) = await _androidUnlocked(tester);

    await robot.openSettings();
    expect(find.text('Integraciones'), findsOneWidget);
    expect(find.text('Navegador'), findsNothing, reason: 'es de escritorio');
    await robot.tapText('Autocompletado');
    await robot.tapText('Activar como autocompletado');

    expect(app.autofillSettings.opened, 1);
  });

  testWidgets('si el sistema no abre los ajustes de autocompletado, lo avisa', (
    tester,
  ) async {
    final (app, robot) = await _androidUnlocked(tester);
    app.autofillSettings.canOpen = false;

    await robot.openSettings();
    expect(find.text('Integraciones'), findsOneWidget);
    expect(find.text('Navegador'), findsNothing, reason: 'es de escritorio');
    await robot.tapText('Autocompletado');
    await robot.tapText('Activar como autocompletado');

    expect(find.text('No se pudo abrir la configuración.'), findsOneWidget);
  });

  testWidgets('el ícono del lanzador sigue al tema elegido (ADR 0031)', (
    tester,
  ) async {
    final (app, robot) = await _androidUnlocked(tester);
    expect(app.launcherIcon.themes, [ThemeFamilyId.lineage]);

    await robot.openSettings();
    await robot.tapText('Apariencia');
    expect(
      find.textContaining('El ícono de Lockspire en el teléfono'),
      findsOneWidget,
    );
    await robot.tapText('Linux Mint');

    expect(app.launcherIcon.themes.last, ThemeFamilyId.mint);
  });

  testWidgets('fuera de Android no se toca el ícono del lanzador', (
    tester,
  ) async {
    final app = TestApp();
    await app.pump(tester);

    expect(app.launcherIcon.themes, isEmpty);
    expect(find.text('Activar como autocompletado'), findsNothing);
  });
}
