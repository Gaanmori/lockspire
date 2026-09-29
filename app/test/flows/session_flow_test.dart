// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Gabriel Ángel Montoya Rico

import 'package:flutter_test/flutter_test.dart';

import '../support/app_robot.dart';
import '../support/test_app.dart';

const _master = 'correcto caballo batería grapa';

void main() {
  testWidgets('bloquear pide la contraseña maestra; una incorrecta se '
      'rechaza y la correcta devuelve las entradas', (tester) async {
    final app = TestApp();
    await app.pump(tester);
    final robot = AppRobot(tester);
    await robot.createVault(_master);
    await robot.addPassword(title: 'Banco');

    await robot.lock();
    expect(find.text('Banco'), findsNothing);
    expect(find.text('¡Hola de nuevo!'), findsOneWidget);

    await robot.unlock('no es esta');
    expect(find.text('Contraseña incorrecta'), findsOneWidget);
    expect(find.text('Banco'), findsNothing);

    await robot.unlock(_master);
    expect(find.text('Banco'), findsOneWidget);
  });

  testWidgets('al volver a abrir la app, la bóveda guardada se abre con su '
      'contraseña y conserva las entradas', (tester) async {
    final first = TestApp();
    await first.pump(tester);
    final robot = AppRobot(tester);
    await robot.createVault(_master);
    await robot.addPassword(title: 'Banco', username: 'ana');

    // Otro arranque sobre el mismo archivo de bóveda.
    final reopened = TestApp(storage: first.storage, crypto: first.crypto);
    await reopened.pump(tester);

    expect(find.text('¡Hola de nuevo!'), findsOneWidget);
    await robot.unlock(_master);
    expect(find.text('Banco'), findsOneWidget);
  });
}
