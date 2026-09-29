// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Gabriel Ángel Montoya Rico

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/app_robot.dart';
import '../support/test_app.dart';

Future<(TestApp, AppRobot)> _about(WidgetTester tester) async {
  final app = TestApp();
  await app.pump(tester);
  final robot = AppRobot(tester);
  await robot.createVault('correcto caballo batería grapa');
  await robot.openSettings();
  await robot.tapText('Acerca de');
  return (app, robot);
}

/// Acerca de (ADR 0028): la AGPLv3 pide ofrecer el código fuente.
void main() {
  testWidgets('muestra la versión instalada y el autor', (tester) async {
    await _about(tester);

    expect(find.text('Versión 1.2.3 (45)'), findsOneWidget);
    expect(find.text('Gabriel Ángel Montoya Rico'), findsOneWidget);
  });

  testWidgets('los enlaces se abren en el navegador: código fuente, '
      'licencia y política de privacidad', (tester) async {
    final (app, robot) = await _about(tester);

    for (final link in [
      'Código fuente',
      'Licencia',
      'Política de privacidad',
    ]) {
      await robot.reveal(find.text(link));
      await robot.tapText(link);
    }

    expect(app.links.opened.map((u) => u.host), [
      'github.com',
      'www.gnu.org',
      'gaanmori.github.io',
    ]);
  });

  testWidgets('si no hay navegador para abrir el enlace, lo avisa', (
    tester,
  ) async {
    final (app, robot) = await _about(tester);
    app.links.canOpen = false;

    await robot.reveal(find.text('Código fuente'));
    await robot.tapText('Código fuente');

    expect(
      find.text('No se pudo abrir https://github.com/Gaanmori/lockspire'),
      findsOneWidget,
    );
  });

  testWidgets('las licencias de terceros abren la página de licencias', (
    tester,
  ) async {
    final (_, robot) = await _about(tester);

    await robot.reveal(find.text('Licencias de terceros'));
    await robot.tapText('Licencias de terceros');

    expect(find.byType(LicensePage), findsOneWidget);
  });
}
