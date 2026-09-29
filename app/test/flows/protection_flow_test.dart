// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Gabriel Ángel Montoya Rico

import 'package:flutter_test/flutter_test.dart';

import '../support/app_robot.dart';
import '../support/test_app.dart';

const _master = 'correcto caballo batería grapa';

/// Protecciones que corren solas: el portapapeles se limpia y la bóveda se
/// bloquea sin que el usuario haga nada (ADR 0008, 0016; hallazgo S4).
void main() {
  testWidgets('copiar la contraseña la manda al portapapeles protegido, y '
      'bloquear lo limpia', (tester) async {
    final app = TestApp();
    await app.pump(tester);
    final robot = AppRobot(tester);
    await robot.createVault(_master);
    await robot.addPassword(title: 'Banco', password: 'Secreta-123');

    await robot.openEntry('Banco');
    await robot.tapTooltip('Copiar contraseña');
    expect(app.clipboard.copies, ['Secreta-123']);
    expect(app.clipboard.delays.single, const Duration(seconds: 30));
    expect(
      find.text('Copiado: Contraseña. Se borra en 30 s o al bloquear'),
      findsOneWidget,
    );

    final clearsBefore = app.clipboard.clears;
    await robot.systemBack();
    await robot.lock();
    expect(app.clipboard.clears, greaterThan(clearsBefore));
  });

  testWidgets('sin usar la app, la bóveda se bloquea sola a los 5 minutos '
      '(el valor por defecto)', (tester) async {
    await TestApp().pump(tester);
    final robot = AppRobot(tester);
    await robot.createVault(_master);
    await robot.addPassword(title: 'Banco');

    await tester.pump(const Duration(minutes: 4));
    expect(find.text('Banco'), findsOneWidget);

    await tester.pump(const Duration(minutes: 2));
    await tester.pumpAndSettle();
    expect(find.text('Banco'), findsNothing);
    expect(find.text('¡Hola de nuevo!'), findsOneWidget);
  });

  // Regresión (2026-09-29, encontrada por este test): el teclado en pantalla
  // no produce eventos de teclado físico ni toques en la app, así que
  // escribir no contaba como actividad y la bóveda se bloqueaba (cerrando
  // el formulario sin guardar) a mitad de una nota larga.
  testWidgets('escribir con el teclado en pantalla, sin tocar la app, cuenta '
      'como actividad', (tester) async {
    await TestApp().pump(tester);
    final robot = AppRobot(tester);
    await robot.createVault(_master);
    await robot.startNewPassword();

    await tester.pump(const Duration(minutes: 4));
    // enterText llega por el canal del método de entrada, como el teclado
    // en pantalla: sin toques ni teclas físicas.
    await tester.enterText(robot.field('Notas'), 'Una nota larga…');
    await tester.pump(const Duration(minutes: 4));

    expect(find.text('Notas'), findsOneWidget, reason: 'el formulario sigue');
    expect(find.text('¡Hola de nuevo!'), findsNothing);
  });
}
