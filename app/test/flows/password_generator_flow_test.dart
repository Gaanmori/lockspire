// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Gabriel Ángel Montoya Rico

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/app_robot.dart';
import '../support/test_app.dart';

String _passwordIn(WidgetTester tester) => tester
    .widget<TextField>(find.widgetWithText(TextField, 'Contraseña'))
    .controller!
    .text;

int _shownLength(WidgetTester tester) {
  final label = tester
      .widgetList<Text>(find.textContaining(' caracteres'))
      .map((t) => t.data!)
      .single;
  return int.parse(label.split(' ').first);
}

Future<AppRobot> _newPasswordForm(WidgetTester tester) async {
  await TestApp().pump(tester);
  final robot = AppRobot(tester);
  await robot.createVault('correcto caballo batería grapa');
  await robot.startNewPassword();
  await robot.tapTooltip('Generar contraseña');
  return robot;
}

void main() {
  testWidgets('el dado genera una contraseña del largo que muestra el panel', (
    tester,
  ) async {
    await _newPasswordForm(tester);

    expect(_passwordIn(tester), hasLength(_shownLength(tester)));
  });

  // Regresión (2026-09-29, encontrada por el usuario): el slider
  // regeneraba la contraseña con el largo nuevo, pero no se movía ni
  // actualizaba "N caracteres".
  testWidgets('mover el slider cambia el largo mostrado y el de la '
      'contraseña', (tester) async {
    await _newPasswordForm(tester);
    final before = _shownLength(tester);

    await tester.drag(find.byType(Slider), const Offset(400, 0));
    await tester.pumpAndSettle();

    final after = _shownLength(tester);
    expect(after, greaterThan(before));
    expect(tester.widget<Slider>(find.byType(Slider)).value, after);
    expect(_passwordIn(tester), hasLength(after));
  });

  testWidgets('una entrada nueva arranca en "fácil de recordar": palabras '
      'con un dígito cada una', (tester) async {
    await _newPasswordForm(tester);

    final password = _passwordIn(tester);
    expect(password, hasLength(_shownLength(tester)));
    expect(
      password,
      matches(RegExp(r'^[A-Z][a-z]+[0-9]+([^A-Za-z0-9][A-Z][a-z]+[0-9]+)*$')),
    );
  });

  testWidgets('cambiar a "Aleatoria" regenera con las cuatro clases de '
      'caracteres', (tester) async {
    await _newPasswordForm(tester);

    await tester.tap(find.text('Fácil de recordar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Aleatoria').last);
    await tester.pumpAndSettle();

    final password = _passwordIn(tester);
    expect(password, hasLength(_shownLength(tester)));
    for (final charClass in [r'[a-z]', r'[A-Z]', r'[0-9]', r'[^A-Za-z0-9]']) {
      expect(password, matches(RegExp(charClass)));
    }
  });
}
