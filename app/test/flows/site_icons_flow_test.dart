// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Gabriel Ángel Montoya Rico

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/app_robot.dart';
import '../support/fakes/fake_site_icons.dart';
import '../support/test_app.dart';

Future<(TestApp, AppRobot)> _withEntries(WidgetTester tester) async {
  final app = TestApp();
  app.siteIcons.icons['banco.ejemplo'] = tinyPng;
  app.siteIconsFallback.icons['correo.ejemplo'] = tinyPng;
  await app.pump(tester);
  final robot = AppRobot(tester);
  await robot.createVault('correcto caballo batería grapa');
  await robot.addPassword(
    title: 'Banco',
    username: 'ana',
    url: 'https://www.banco.ejemplo/login',
  );
  await robot.addPassword(title: 'Correo', url: 'https://correo.ejemplo');
  return (app, robot);
}

/// Los íconos se activan en Ajustes → Apariencia (revisión de ajustes
/// 2026-09-30).
Future<void> _turnOn(AppRobot robot, String option) async {
  await robot.openSettings();
  await robot.tapText('Apariencia');
  await robot.reveal(find.text(option));
  await robot.tapText(option);
  await robot.systemBack();
  await robot.tapText('Bóveda');
}

/// Íconos de los sitios (ADR 0029, 0030): opcionales, directos del sitio y,
/// si se pide, con DuckDuckGo para los que falten.
void main() {
  testWidgets('apagados (por defecto) no se pide nada a ningún sitio', (
    tester,
  ) async {
    final (app, robot) = await _withEntries(tester);

    expect(app.siteIcons.asked, isEmpty);
    expect(app.siteIconsFallback.asked, isEmpty);
    expect(find.byType(Image), findsNothing);
  });

  testWidgets('al activarlos se piden a cada sitio, solo con su dominio, y '
      'la lista los muestra', (tester) async {
    final (app, robot) = await _withEntries(tester);

    // Regresión (2026-09-29, encontrada por este test): activar no buscaba
    // nada hasta el siguiente guardado.
    await _turnOn(robot, 'Íconos de los sitios');

    expect(
      app.siteIcons.asked,
      containsAll(['banco.ejemplo', 'correo.ejemplo']),
    );
    // Nunca sale el usuario ni la ruta: solo el dominio, sin "www".
    expect(app.siteIcons.asked.join(), isNot(contains('ana')));
    expect(app.siteIcons.asked.join(), isNot(contains('login')));
    expect(find.byType(Image), findsOneWidget);
    // Sin el respaldo activado, DuckDuckGo no recibe nada.
    expect(app.siteIconsFallback.asked, isEmpty);
  });

  testWidgets('con el respaldo, DuckDuckGo recibe solo los dominios sin '
      'ícono propio', (tester) async {
    final (app, robot) = await _withEntries(tester);

    await _turnOn(robot, 'Íconos de los sitios');
    await _turnOn(robot, 'Completar los que falten con DuckDuckGo');

    expect(app.siteIconsFallback.asked, ['correo.ejemplo']);
    expect(find.byType(Image), findsNWidgets(2));
  });
}
