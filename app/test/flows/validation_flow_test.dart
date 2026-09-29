// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Gabriel Ángel Montoya Rico

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/app_robot.dart';
import '../support/fakes/sync_fakes.dart';
import '../support/test_app.dart';

const _master = 'correcto caballo batería grapa';

/// Lo que los formularios no dejan pasar, con el mensaje que ve el usuario.
void main() {
  group('Crear la bóveda', () {
    testWidgets('una contraseña corta o fácil de adivinar no se acepta', (
      tester,
    ) async {
      await TestApp().pump(tester);
      final robot = AppRobot(tester);

      await robot.type('Contraseña maestra', 'corta');
      await robot.type('Confirmar contraseña', 'corta');
      await robot.tapButton('Crear bóveda');
      expect(find.textContaining('Use al menos'), findsOneWidget);

      await robot.type('Contraseña maestra', 'aaaaaaaaaaaaaaaa');
      await robot.type('Confirmar contraseña', 'aaaaaaaaaaaaaaaa');
      await robot.tapButton('Crear bóveda');
      expect(
        find.text('Tiene demasiados caracteres repetidos'),
        findsOneWidget,
      );
    });

    testWidgets('la confirmación tiene que coincidir', (tester) async {
      await TestApp().pump(tester);
      final robot = AppRobot(tester);

      await robot.type('Contraseña maestra', _master);
      await robot.type('Confirmar contraseña', '$_master!');
      await robot.tapButton('Crear bóveda');

      expect(
        find.text('No coincide con la contraseña anterior'),
        findsOneWidget,
      );
    });
  });

  group('Cambiar la contraseña maestra', () {
    Future<AppRobot> openChange(WidgetTester tester) async {
      await TestApp().pump(tester);
      final robot = AppRobot(tester);
      await robot.createVault(_master);
      await robot.tapText('Seguridad');
      await robot.tapText('Cambiar contraseña maestra');
      return robot;
    }

    testWidgets('con la contraseña actual equivocada no cambia nada', (
      tester,
    ) async {
      final robot = await openChange(tester);

      await robot.type('Contraseña actual', 'no es esta');
      await robot.type('Contraseña nueva', 'Otra frase-muy larga 2026!');
      await robot.type(
        'Confirmar contraseña nueva',
        'Otra frase-muy larga 2026!',
      );
      await robot.tapButton('Cambiar contraseña');

      expect(find.text('La contraseña actual no es correcta'), findsOneWidget);
    });

    testWidgets('la nueva tiene que ser distinta de la actual y coincidir con '
        'su confirmación', (tester) async {
      final robot = await openChange(tester);

      await robot.type('Contraseña actual', _master);
      await robot.type('Contraseña nueva', _master);
      await robot.type('Confirmar contraseña nueva', 'otra cosa');
      await robot.tapButton('Cambiar contraseña');

      expect(find.text('Tiene que ser distinta de la actual'), findsOneWidget);
      expect(find.text('No coincide con la contraseña nueva'), findsOneWidget);
    });

    testWidgets('"Mostrar contraseñas" las deja ver', (tester) async {
      final robot = await openChange(tester);
      bool obscured() => tester
          .widget<TextField>(robot.field('Contraseña actual'))
          .obscureText;
      expect(obscured(), isTrue);

      await robot.tapText('Mostrar contraseñas');

      expect(obscured(), isFalse);
    });
  });

  group('Restaurar desde la nube', () {
    testWidgets('si la nube no tiene bóveda, lo explica y permite volver', (
      tester,
    ) async {
      await TestApp(cloud: FakeSyncPort()).pump(tester);
      final robot = AppRobot(tester);

      await robot.tapText('¿Ya tiene una bóveda? Restaurarla desde la nube');
      await robot.tapText('Configurar proveedor de sync');
      await robot.configureWebdav();

      expect(find.text('No hay ninguna bóveda ahí todavía'), findsOneWidget);
      await robot.tapText('Volver');
      expect(find.text('Buscar mi bóveda'), findsOneWidget);
    });

    testWidgets('con la contraseña equivocada no restaura', (tester) async {
      final cloud = FakeSyncPort();
      final phone = TestApp(cloud: cloud);
      await phone.pump(tester);
      final robot = AppRobot(tester);
      await robot.createVault(_master);
      await robot.openSync();
      await robot.configureWebdav();

      await TestApp(cloud: cloud, crypto: phone.crypto).pump(tester);
      await robot.tapText('¿Ya tiene una bóveda? Restaurarla desde la nube');
      await robot.tapText('Configurar proveedor de sync');
      await robot.configureWebdav();
      await robot.type('Contraseña maestra', 'no es esta');
      await robot.tapButton('Restaurar bóveda');

      expect(find.text('Contraseña incorrecta'), findsOneWidget);
      expect(find.text('Encontramos su bóveda'), findsOneWidget);
    });
  });

  group('Formulario de una entrada', () {
    testWidgets('se agregan y quitan sitios, apps y campos a medida', (
      tester,
    ) async {
      await TestApp().pump(tester);
      final robot = AppRobot(tester);
      await robot.createVault(_master);
      await robot.startNewPassword();
      await robot.type('Título', 'Banco');

      await robot.tapText('Agregar sitio web');
      expect(find.widgetWithText(TextField, 'Sitio web 2'), findsOneWidget);
      await robot.tapText('App Android');
      await robot.type('App (paquete)', 'com.banco.app');
      await robot.tapText('Campo');
      await robot.type('Nombre del campo', 'PIN del cajero');
      await robot.tapText('Agregar');
      await robot.type('PIN del cajero', '1234');

      await robot.tapTooltip('Quitar campo');
      expect(find.widgetWithText(TextField, 'PIN del cajero'), findsNothing);
      await robot.save();

      await robot.openEntry('Banco');
      expect(find.text('com.banco.app'), findsOneWidget);
    });

    testWidgets('un nombre de campo repetido no se acepta', (tester) async {
      await TestApp().pump(tester);
      final robot = AppRobot(tester);
      await robot.createVault(_master);
      await robot.startNewPassword();

      await robot.tapText('Campo');
      await robot.type('Nombre del campo', 'Pregunta');
      await robot.tapText('Agregar');
      await robot.reveal(find.text('Agregar campo'));
      await robot.tapText('Agregar campo');
      await robot.type('Nombre del campo', 'Pregunta');
      await robot.tapText('Agregar');

      expect(find.text('Ya hay un campo con ese nombre'), findsOneWidget);
    });
  });
}
