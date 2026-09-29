// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Gabriel Ángel Montoya Rico

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/test_app.dart';

void main() {
  testWidgets('primer arranque: crea la bóveda y entra a una bóveda vacía', (
    tester,
  ) async {
    final app = TestApp();
    await app.pump(tester);

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Contraseña maestra'),
      'correcto caballo batería grapa',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Confirmar contraseña'),
      'correcto caballo batería grapa',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Crear bóveda'));
    await tester.pumpAndSettle();

    expect(
      find.text('Todavía no ha guardado ninguna contraseña'),
      findsOneWidget,
    );
    expect(app.storage.stored, isNotNull);
  });
}
