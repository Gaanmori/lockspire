// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Gabriel Ángel Montoya Rico

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/app_robot.dart';
import '../support/test_app.dart';

void main() {
  // Regresión (2026-09-29, encontrada al escribir este test): el aviso iba de
  // lado a lado y tapaba "Bloquear" al pie del riel.
  testWidgets('en escritorio, un aviso no tapa "Bloquear" al pie del riel', (
    tester,
  ) async {
    await TestApp().pump(tester, size: desktopSize, pixelRatio: 1);
    final robot = AppRobot(tester);
    await robot.createVault('correcto caballo batería grapa');
    await robot.addPassword(title: 'Banco');

    // Eliminar por selección muestra un aviso abajo.
    await robot.tapTooltip('Seleccionar');
    await robot.tapTooltip('Seleccionar todo');
    await robot.tapTooltip('Eliminar seleccionadas');
    await tester.tap(find.widgetWithText(FilledButton, 'Eliminar'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('Se eliminó 1 entrada'), findsOneWidget);
    // El Material visible del aviso (la caja del SnackBar incluye sus
    // márgenes).
    final snack = tester.getRect(
      find
          .descendant(
            of: find.byType(SnackBar),
            matching: find.byType(Material),
          )
          .first,
    );
    final lock = tester.getRect(find.byTooltip('Bloquear').first);
    expect(snack.overlaps(lock), isFalse, reason: 'aviso $snack, botón $lock');
    // Y se puede bloquear sin esperar a que el aviso se vaya.
    await tester.tap(find.byTooltip('Bloquear').first);
    await tester.pumpAndSettle();
    expect(find.text('¡Hola de nuevo!'), findsOneWidget);
  });
}
