// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Gabriel Ángel Montoya Rico

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/app_robot.dart';
import '../support/test_app.dart';

void main() {
  testWidgets('con el sistema en inglés, la app arranca en inglés', (
    tester,
  ) async {
    await TestApp().pump(tester, systemLocale: const Locale('en', 'US'));

    expect(find.text('Create your vault'), findsOneWidget);
  });

  testWidgets('con el sistema en otro idioma, la app usa inglés', (
    tester,
  ) async {
    await TestApp().pump(tester, systemLocale: const Locale('pt', 'BR'));

    expect(find.text('Create your vault'), findsOneWidget);
  });

  testWidgets('elegir English en Apariencia traduce la app al instante, y '
      'volver a Sistema la deja en el idioma del sistema', (tester) async {
    await TestApp().pump(tester);
    final robot = AppRobot(tester);
    await robot.createVault('correcto caballo batería grapa');

    await robot.openSettings();
    await robot.tapText('Apariencia');
    await robot.tapText('English');
    expect(find.text('Appearance'), findsOneWidget);
    expect(find.text('Language'), findsOneWidget);

    // "System" está dos veces: en Language y en Mode. La primera es la del
    // idioma.
    await tester.tap(find.text('System').first);
    await tester.pumpAndSettle();
    expect(find.text('Apariencia'), findsOneWidget);
  });
}
