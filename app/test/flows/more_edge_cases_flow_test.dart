// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Gabriel Ángel Montoya Rico

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lockspire/features/autofill/domain/ports/autofill_host_port.dart';

import '../support/app_robot.dart';
import '../support/fakes/fake_site_icons.dart';
import '../support/fakes/sync_fakes.dart';
import '../support/test_app.dart';

const _master = 'correcto caballo batería grapa';
const _diskFull = FileSystemException('No queda espacio en el disco');

Future<(TestApp, AppRobot)> _unlocked(
  WidgetTester tester, [
  TestApp? app,
]) async {
  final testApp = app ?? TestApp();
  await testApp.pump(tester);
  final robot = AppRobot(tester);
  await robot.createVault(_master);
  return (testApp, robot);
}

void main() {
  group('Autocompletado con una entrada sin sitio (ADR 0020)', () {
    Future<(TestApp, AppRobot)> fillFromApp(WidgetTester tester) async {
      final (app, robot) = await _unlocked(tester, TestApp(android: true));
      await robot.addPassword(title: 'Banco', username: 'ana', password: 'x1');
      await robot.addPassword(title: 'Correo', username: 'ana@c');
      await app.pumpAutofill(
        tester,
        const AutofillFillRequest(
          packageName: 'com.android.chrome',
          origin: 'https://banco.ejemplo',
        ),
      );
      await robot.unlock(_master);
      return (app, robot);
    }

    testWidgets('"Solo esta vez" rellena sin guardar el sitio', (tester) async {
      final (app, robot) = await fillFromApp(tester);

      await robot.tapText('Banco');
      expect(find.text('Esta entrada no tiene sitio'), findsOneWidget);
      await robot.tapText('Solo esta vez');

      expect(app.autofillHost.filled, (username: 'ana', password: 'x1'));
    });

    testWidgets('"Rellenar y recordar" guarda el sitio en la entrada', (
      tester,
    ) async {
      final (app, robot) = await fillFromApp(tester);

      await robot.tapText('Banco');
      await robot.tapText('Rellenar y recordar');

      expect(app.autofillHost.filled, isNotNull);
      await app.pump(tester);
      await robot.unlock(_master);
      await robot.openEntry('Banco');
      expect(find.text('https://banco.ejemplo'), findsOneWidget);
    });

    testWidgets('se puede buscar entre las entradas', (tester) async {
      await fillFromApp(tester);

      await tester.enterText(
        find.widgetWithText(TextField, 'Buscar por título'),
        'corr',
      );
      await tester.pumpAndSettle();

      expect(find.text('Correo'), findsOneWidget);
      expect(find.text('Banco'), findsNothing);

      await tester.enterText(
        find.widgetWithText(TextField, 'Buscar por título'),
        'nada',
      );
      await tester.pumpAndSettle();
      expect(find.text('No se encontraron resultados.'), findsOneWidget);
    });
  });

  testWidgets('"Volver a buscar los que faltan" vuelve a pedir los íconos que '
      'antes no estaban', (tester) async {
    final (app, robot) = await _unlocked(tester);
    await robot.addPassword(title: 'Banco', url: 'https://banco.ejemplo');
    await robot.tapText('Seguridad');
    await robot.reveal(find.text('Íconos de los sitios'));
    await robot.tapText('Íconos de los sitios');
    expect(app.siteIcons.asked, ['banco.ejemplo']);

    // El sitio ahora sí publica su ícono.
    app.siteIcons.icons['banco.ejemplo'] = tinyPng;
    await robot.reveal(find.text('Volver a buscar los que faltan'));
    await robot.tapText('Volver a buscar los que faltan');

    expect(app.siteIcons.asked, ['banco.ejemplo', 'banco.ejemplo']);
    await robot.tapText('Bóveda');
    expect(find.byType(Image), findsOneWidget);
  });

  testWidgets('restaurar sin conexión explica que no pudo buscar', (
    tester,
  ) async {
    final cloud = FakeSyncPort()..offline = true;
    await TestApp(cloud: cloud).pump(tester);
    final robot = AppRobot(tester);

    await robot.tapText('¿Ya tiene una bóveda? Restaurarla desde la nube');
    await robot.tapText('Configurar proveedor de sync');
    await robot.configureWebdav();

    expect(
      find.textContaining('No se pudo buscar la bóveda remota'),
      findsOneWidget,
    );
    cloud.offline = false;
    await robot.tapText('Buscar mi bóveda');
    expect(find.text('No hay ninguna bóveda ahí todavía'), findsOneWidget);
  });

  group('Sin espacio en el disco', () {
    testWidgets('guardar una entrada lo dice y no cierra el formulario', (
      tester,
    ) async {
      final (app, robot) = await _unlocked(tester);
      await robot.startNewPassword();
      await robot.type('Título', 'Banco');

      app.storage.writeError = _diskFull;
      await robot.save();

      expect(find.textContaining('No se pudo guardar'), findsOneWidget);
      expect(find.text('Nueva contraseña'), findsOneWidget);
    });

    testWidgets('crear la bóveda lo dice', (tester) async {
      final app = TestApp();
      app.storage.writeError = _diskFull;
      await app.pump(tester);

      await AppRobot(tester).createVault(_master);

      expect(find.textContaining('No se pudo crear la bóveda'), findsOneWidget);
    });

    testWidgets('cambiar la contraseña maestra lo dice y la deja igual', (
      tester,
    ) async {
      final (app, robot) = await _unlocked(tester);
      await robot.tapText('Seguridad');
      await robot.tapText('Cambiar contraseña maestra');
      await robot.type('Contraseña actual', _master);
      await robot.type('Contraseña nueva', 'Otra frase-muy larga 2026!');
      await robot.type(
        'Confirmar contraseña nueva',
        'Otra frase-muy larga 2026!',
      );

      app.storage.writeError = _diskFull;
      await robot.tapButton('Cambiar contraseña');

      expect(
        find.textContaining('No se pudo cambiar la contraseña'),
        findsOneWidget,
      );
      app.storage.writeError = null;
      await robot.systemBack();
      await robot.lock();
      await robot.unlock(_master);
      expect(find.text('¡Hola de nuevo!'), findsNothing);
    });
  });
}
