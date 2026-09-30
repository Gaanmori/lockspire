// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Gabriel Ángel Montoya Rico

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lockspire/features/about/domain/ports/donation_port.dart';

import '../support/app_robot.dart';
import '../support/test_app.dart';

Future<(TestApp, AppRobot)> _about(
  WidgetTester tester, {
  void Function(TestApp app)? before,
}) async {
  final app = TestApp();
  before?.call(app);
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

  group('Invíteme un café (ADR 0033)', () {
    testWidgets('con Google Play: tres montos con su precio, y agradece al '
        'pagar', (tester) async {
      final (app, robot) = await _about(tester);

      await robot.reveal(find.text('Invíteme un café'));
      expect(find.text(r'$ 5.000'), findsOneWidget);
      await robot.tapText('Café y pastel');

      expect(app.donations.donated, [DonationTier.coffeeAndCake]);
      expect(find.text('¡Gracias por su apoyo!'), findsOneWidget);
    });

    testWidgets('un pago cancelado no dice nada; uno fallido lo '
        'avisa', (tester) async {
      final (app, robot) = await _about(tester);
      await robot.reveal(find.text('Un almuerzo'));

      app.donations.outcome = DonationOutcome.cancelled;
      await robot.tapText('Un almuerzo');
      expect(find.byType(SnackBar), findsNothing);

      app.donations.outcome = DonationOutcome.failed;
      await robot.tapText('Un almuerzo');
      expect(
        find.text(
          'No se pudo completar la donación. Inténtelo de nuevo más tarde.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('si no hay cómo donar, la sección no aparece', (tester) async {
      await _about(tester, before: (app) => app.donations.available = []);

      expect(find.text('Invíteme un café'), findsNothing);
    });
  });
}
