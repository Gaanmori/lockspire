// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Gabriel Ángel Montoya Rico

import 'package:flutter_test/flutter_test.dart';
import 'package:lockspire/features/desktop/domain/ports/tray_port.dart';

import '../support/app_robot.dart';
import '../support/test_app.dart';

const _master = 'correcto caballo batería grapa';

Future<(TestApp, AppRobot)> _desktopUnlocked(WidgetTester tester) async {
  final app = TestApp(desktop: true);
  await app.pump(tester);
  final robot = AppRobot(tester);
  await robot.createVault(_master);
  return (app, robot);
}

/// Escritorio con bandeja (ADR 0012): cerrar la ventana la oculta, y desde
/// la bandeja se abre, se bloquea o se sale.
void main() {
  testWidgets('cerrar la ventana la primera vez explica que sigue en la '
      'bandeja; después la oculta sin preguntar', (tester) async {
    final (app, robot) = await _desktopUnlocked(tester);
    expect(app.window.intercepting, isTrue);

    app.window.requestClose();
    await robot.settle();
    expect(find.text('Lockspire sigue abierto'), findsOneWidget);
    await robot.tapText('Entendido');
    expect(app.window.visible, isFalse);

    await app.window.show();
    app.window.requestClose();
    await robot.settle();
    expect(find.text('Lockspire sigue abierto'), findsNothing);
    expect(app.window.visible, isFalse);
  });

  testWidgets('el menú de la bandeja está en el idioma de la app y ofrece '
      'bloquear solo con la bóveda abierta', (tester) async {
    final (app, robot) = await _desktopUnlocked(tester);
    expect(app.tray.menu!.open, 'Abrir Lockspire');
    expect(app.tray.menu!.quit, 'Salir');
    expect(app.tray.menu!.lockEnabled, isTrue);

    app.tray.choose(TrayAction.lock);
    await robot.settle();

    expect(find.text('¡Hola de nuevo!'), findsOneWidget);
    expect(app.tray.menu!.lockEnabled, isFalse);
  });

  testWidgets('cambiar el idioma rearma el menú de la bandeja', (tester) async {
    final (app, robot) = await _desktopUnlocked(tester);

    await robot.openSettings();
    await robot.tapText('Apariencia');
    await robot.tapText('English');

    expect(app.tray.menu!.open, 'Open Lockspire');
    expect(app.tray.menu!.quit, 'Quit');
  });

  testWidgets('abrir desde la bandeja vuelve a mostrar la ventana', (
    tester,
  ) async {
    final (app, robot) = await _desktopUnlocked(tester);
    await app.window.hide();

    app.tray.choose(TrayAction.open);
    await robot.settle();

    expect(app.window.visible, isTrue);
  });

  testWidgets('salir bloquea, limpia el portapapeles y cierra de verdad', (
    tester,
  ) async {
    final (app, robot) = await _desktopUnlocked(tester);
    await robot.addPassword(title: 'Banco', password: 'Secreta-123');
    await robot.openEntry('Banco');
    await robot.tapTooltip('Copiar contraseña');
    final clearsBefore = app.clipboard.clears;

    app.tray.choose(TrayAction.quit);
    await robot.settle();

    expect(find.text('¡Hola de nuevo!'), findsOneWidget);
    expect(app.clipboard.clears, greaterThan(clearsBefore));
    expect(app.tray.destroyed, isTrue);
    expect(app.window.intercepting, isFalse);
    expect(app.window.destroyed, isTrue);
  });

  testWidgets('bloquear la sesión del sistema bloquea la bóveda', (
    tester,
  ) async {
    final (app, robot) = await _desktopUnlocked(tester);

    app.osSession.lockSession();
    await robot.settle();

    expect(find.text('¡Hola de nuevo!'), findsOneWidget);
  });

  testWidgets('el ícono de la ventana y de la bandeja sigue al tema', (
    tester,
  ) async {
    final (app, robot) = await _desktopUnlocked(tester);
    final before = app.window.icon;
    expect(app.tray.icon, before);

    await robot.openSettings();
    await robot.tapText('Apariencia');
    await robot.tapText('Ubuntu');

    expect(app.window.icon, isNot(before));
    expect(app.tray.icon, app.window.icon);
  });
}
