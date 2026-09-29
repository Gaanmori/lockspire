// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Gabriel Ángel Montoya Rico

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/app_robot.dart';
import '../support/test_app.dart';

String _textOf(WidgetTester tester, Finder field) =>
    tester.widget<TextField>(field).controller!.text;

Future<AppRobot> _unlocked(WidgetTester tester) async {
  await TestApp().pump(tester);
  final robot = AppRobot(tester);
  await robot.createVault('correcto caballo batería grapa');
  return robot;
}

/// Tarjetas y documentos (ADR 0025): sus campos fijos se guardan, se
/// vuelven a mostrar y la lista no deja ver el número completo.
void main() {
  testWidgets('una tarjeta guarda sus datos y la lista muestra solo los '
      'últimos 4 dígitos', (tester) async {
    final robot = await _unlocked(tester);

    await robot.tapTooltip('Agregar');
    await robot.tapText('Tarjeta');
    expect(find.text('Nueva tarjeta'), findsOneWidget);
    await robot.type('Título', 'Visa');
    await robot.type('Número de tarjeta', '4111 1111 1111 4242');
    await robot.type('Titular', 'ANA PÉREZ');
    await robot.type('Vence', '09/29');
    await robot.type('CVV', '123');
    await robot.save();

    expect(find.text('Visa'), findsOneWidget);
    expect(find.text('•••• 4242 · ANA PÉREZ'), findsOneWidget);
    expect(find.textContaining('4111'), findsNothing);

    await robot.openEntry('Visa');
    expect(find.text('Editar tarjeta'), findsOneWidget);
    expect(_textOf(tester, robot.field('Titular')), 'ANA PÉREZ');
    expect(_textOf(tester, robot.field('CVV')), '123');
  });

  testWidgets('un documento guarda número, nombre y fechas', (tester) async {
    final robot = await _unlocked(tester);

    await robot.tapTooltip('Agregar');
    await robot.tapText('Documento');
    expect(find.text('Nuevo documento'), findsOneWidget);
    await robot.type('Título', 'Cédula');
    await robot.type('Número', '1.234.567');
    await robot.type('Nombre', 'Ana Pérez');
    await robot.type('Fecha de nacimiento', '01/02/1990');
    await robot.save();

    await robot.openEntry('Cédula');
    expect(find.text('Editar documento'), findsOneWidget);
    expect(_textOf(tester, robot.field('Número')), '1.234.567');
    expect(_textOf(tester, robot.field('Fecha de nacimiento')), '01/02/1990');
  });

  testWidgets('un campo a medida oculto se guarda y vuelve oculto', (
    tester,
  ) async {
    final robot = await _unlocked(tester);

    await robot.startNewPassword();
    await robot.type('Título', 'Banco');
    await tester.ensureVisible(find.text('Campo'));
    await robot.tapText('Campo');
    await robot.type('Nombre del campo', 'Pregunta secreta');
    await tester.tap(find.text('Ocultar el valor'));
    await tester.pumpAndSettle();
    await robot.tapText('Agregar');
    await robot.type('Pregunta secreta', 'Firulais');
    await robot.save();

    await robot.openEntry('Banco');
    final field = robot.field('Pregunta secreta');
    expect(_textOf(tester, field), 'Firulais');
    expect(tester.widget<TextField>(field).obscureText, isTrue);
  });
}
