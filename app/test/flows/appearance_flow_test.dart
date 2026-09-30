// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Gabriel Ángel Montoya Rico

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lockspire/features/appearance/domain/appearance_preference.dart';
import 'package:lockspire/features/appearance/presentation/appearance_controller.dart';

import '../support/app_robot.dart';
import '../support/test_app.dart';

Future<(TestApp, AppRobot)> _atAppearance(WidgetTester tester) async {
  final app = TestApp();
  await app.pump(tester);
  final robot = AppRobot(tester);
  await robot.createVault('correcto caballo batería grapa');
  await robot.openSettings();
  await robot.tapText('Apariencia');
  return (app, robot);
}

AppearancePreference _preference(TestApp app) =>
    app.container.read(appearanceControllerProvider).value!;

/// Temas por grupos, Grafito por defecto y el tema Personalizado (ADR 0036).
void main() {
  testWidgets('los temas van en grupos y Grafito es el elegido por defecto', (
    tester,
  ) async {
    final (app, robot) = await _atAppearance(tester);

    expect(_preference(app).family, ThemeFamilyId.grafito);
    for (final text in [
      'Lockspire',
      'Grafito',
      'Personalizado',
      'Automático',
      'Colores del sistema',
      'Inspirados en sistemas operativos',
      'LineageOS',
      'Windows 11',
    ]) {
      await robot.reveal(find.text(text));
      expect(find.text(text), findsOneWidget, reason: text);
    }
  });

  testWidgets('Personalizado: se elige uno de los colores sugeridos o '
      'cualquiera en hexadecimal', (tester) async {
    final (app, robot) = await _atAppearance(tester);
    expect(find.byTooltip('#D32F2F'), findsNothing, reason: 'aún no elegido');

    await robot.reveal(find.text('Personalizado'));
    await robot.tapText('Personalizado');
    expect(_preference(app).family, ThemeFamilyId.personalizado);

    await robot.reveal(find.byTooltip('#D32F2F'));
    await robot.tapTooltip('#D32F2F');
    expect(_preference(app).customColorArgb, 0xFFD32F2F);

    final hex = find.widgetWithText(TextField, 'Color en hexadecimal');
    await robot.reveal(hex);
    await tester.enterText(hex, 'no es un color');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await robot.settle();
    expect(find.text('Escriba un color como #6750A4.'), findsOneWidget);
    expect(_preference(app).customColorArgb, 0xFFD32F2F);

    await tester.enterText(hex, '#123456');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await robot.settle();
    expect(_preference(app).customColorArgb, 0xFF123456);
    expect(find.text('Escriba un color como #6750A4.'), findsNothing);
  });
}
