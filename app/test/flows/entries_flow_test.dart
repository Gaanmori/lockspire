// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Gabriel Ángel Montoya Rico

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/app_robot.dart';
import '../support/test_app.dart';

const _master = 'correcto caballo batería grapa';

/// La app con una bóveda recién creada y abierta.
Future<(TestApp, AppRobot)> _unlockedApp(WidgetTester tester) async {
  final app = TestApp();
  await app.pump(tester);
  final robot = AppRobot(tester);
  await robot.createVault(_master);
  return (app, robot);
}

void main() {
  testWidgets('una contraseña agregada aparece en la lista y se encuentra '
      'buscando', (tester) async {
    final (_, robot) = await _unlockedApp(tester);

    await robot.addPassword(
      title: 'Banco',
      username: 'ana',
      password: 'Secreta-123',
    );
    await robot.addPassword(title: 'Correo', username: 'ana@mail.com');

    expect(find.text('Banco'), findsOneWidget);
    expect(find.text('Correo'), findsOneWidget);

    await robot.search('banc');
    expect(find.text('Banco'), findsOneWidget);
    expect(find.text('Correo'), findsNothing);

    await robot.search('nada que ver');
    expect(find.text('No se encontraron resultados'), findsOneWidget);
  });

  testWidgets('editar una entrada guarda el cambio', (tester) async {
    final (_, robot) = await _unlockedApp(tester);
    await robot.addPassword(title: 'Banco', username: 'ana');

    await robot.openEntry('Banco');
    await robot.type('Título', 'Banco Central');
    await robot.save();

    expect(find.text('Banco Central'), findsOneWidget);
    expect(find.text('Banco'), findsNothing);
  });

  testWidgets('eliminar una entrada desde su formulario la quita de la '
      'lista', (tester) async {
    final (_, robot) = await _unlockedApp(tester);
    await robot.addPassword(title: 'Banco');

    await robot.openEntry('Banco');
    await robot.tapTooltip('Eliminar');
    await tester.tap(find.widgetWithText(FilledButton, 'Eliminar'));
    await tester.pumpAndSettle();

    expect(find.text('Banco'), findsNothing);
    expect(
      find.text('Todavía no ha guardado ninguna contraseña'),
      findsOneWidget,
    );
  });

  testWidgets('seleccionar todo y eliminar vacía la bóveda', (tester) async {
    final (_, robot) = await _unlockedApp(tester);
    await robot.addPassword(title: 'Uno');
    await robot.addPassword(title: 'Dos');

    await robot.tapTooltip('Seleccionar');
    await robot.tapTooltip('Seleccionar todo');
    expect(find.text('2 seleccionadas'), findsOneWidget);
    await robot.tapTooltip('Eliminar seleccionadas');
    await tester.tap(find.widgetWithText(FilledButton, 'Eliminar'));
    await tester.pumpAndSettle();

    expect(find.text('Se eliminaron 2 entradas'), findsOneWidget);
    expect(find.text('Uno'), findsNothing);
    expect(find.text('Dos'), findsNothing);
  });

  testWidgets('el título es obligatorio', (tester) async {
    final (_, robot) = await _unlockedApp(tester);

    await robot.startNewPassword();
    await robot.save();

    expect(find.text('Ingrese un título'), findsOneWidget);
  });
}
