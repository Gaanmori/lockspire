// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Gabriel Ángel Montoya Rico

import 'package:flutter_test/flutter_test.dart';

import '../support/app_robot.dart';
import '../support/other_activity.dart';
import '../support/test_app.dart';

const _master = 'correcto caballo batería grapa';

const _chromeCsv =
    'name,url,username,password\n'
    'Banco,https://banco.ejemplo,ana,Secreta-123\n'
    'Correo,https://mail.ejemplo,ana@mail.ejemplo,Otra-456\n';

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

Future<void> _openImport(AppRobot robot) async {
  await robot.openSettings();
  await robot.tapText('Importar');
}

Future<void> _openExport(AppRobot robot) async {
  await robot.openSettings();
  await robot.tapText('Exportar');
}

/// Importar y exportar (ADR 0027), con el selector de archivos en memoria.
void main() {
  group('Importar', () {
    testWidgets('un CSV de Chrome muestra qué se va a importar, lo importa y '
        'avisa que el archivo no está cifrado', (tester) async {
      final (app, robot) = await _unlocked(tester);
      app.files.willPickText('Chrome Passwords.csv', _chromeCsv);

      await _openImport(robot);
      await robot.tapText('Elegir archivo');
      expect(find.text('Se importarán 2 entradas'), findsOneWidget);
      expect(find.text('2 contraseñas'), findsOneWidget);

      await robot.tapButton('Importar');
      expect(find.text('Importación completada'), findsOneWidget);
      expect(
        find.textContaining('el archivo que eligió no está cifrado'),
        findsOneWidget,
      );
      await robot.tapText('Entendido');

      await robot.tapText('Bóveda');
      expect(find.text('Banco'), findsOneWidget);
      expect(find.text('Correo'), findsOneWidget);
    });

    // Regresión (2026-09-30, encontrada al preparar las capturas de Google
    // Play): en Android el selector de archivos es otra Activity. La app
    // pasaba a segundo plano, la bóveda se bloqueaba y el archivo elegido
    // se perdía: importar era imposible.
    testWidgets('abrir el selector no bloquea la bóveda aunque Android mande '
        'la app a segundo plano', (tester) async {
      final (app, robot) = await _unlocked(tester);
      app.files.willPickText('Chrome Passwords.csv', _chromeCsv);
      app.files.whileOpen = () => simulateOtherActivity(tester);

      await _openImport(robot);
      await robot.tapText('Elegir archivo');
      expect(find.text('Se importarán 2 entradas'), findsOneWidget);
      await robot.tapButton('Importar');
      expect(find.text('Importación completada'), findsOneWidget);

      // Fuera del selector, salir de la app sí bloquea.
      simulateOtherActivity(tester);
      await robot.settle();
      expect(find.text('Desbloquear'), findsOneWidget);
    });

    // Regresión (2026-09-29, encontrada por este test): si la bóveda se
    // bloqueaba con el aviso final abierto (por ejemplo, al ir a borrar el
    // archivo como pide el aviso), al cerrarse el aviso la pantalla de
    // Importar hacía `pop` de la pantalla de abajo y la app quedaba en blanco.
    testWidgets('si la bóveda se bloquea con el aviso final abierto, la app '
        'vuelve a la pantalla de desbloqueo (no queda en blanco)', (
      tester,
    ) async {
      final (app, robot) = await _unlocked(tester);
      app.files.willPickText('passwords.csv', _chromeCsv);
      await _openImport(robot);
      await robot.tapText('Elegir archivo');
      await robot.tapButton('Importar');
      expect(find.text('Importación completada'), findsOneWidget);

      await tester.pump(const Duration(minutes: 6)); // bloqueo automático
      await robot.settle();

      expect(find.text('¡Hola de nuevo!'), findsOneWidget);
      await robot.unlock(_master);
      expect(find.text('Banco'), findsOneWidget);
    });

    testWidgets('importar dos veces el mismo archivo no duplica entradas', (
      tester,
    ) async {
      final (app, robot) = await _unlocked(tester);
      app.files.willPickText('passwords.csv', _chromeCsv);
      await _openImport(robot);
      await robot.tapText('Elegir archivo');
      await robot.tapButton('Importar');
      await robot.tapText('Entendido');

      await _openImport(robot);
      await robot.tapText('Elegir archivo');

      expect(find.text('No hay entradas nuevas'), findsOneWidget);
      expect(
        find.text('2 ya estaban en su bóveda y se omiten'),
        findsOneWidget,
      );
    });

    testWidgets('un formato desconocido se rechaza con un mensaje claro', (
      tester,
    ) async {
      final (app, robot) = await _unlocked(tester);
      app.files.willPickText('notas.pdf', 'no es un export');

      await _openImport(robot);
      await robot.tapText('Elegir archivo');

      expect(
        find.textContaining('Formato no reconocido: .pdf'),
        findsOneWidget,
      );
    });

    testWidgets('un JSON de Bitwarden cifrado explica cómo exportarlo bien', (
      tester,
    ) async {
      final (app, robot) = await _unlocked(tester);
      app.files.willPickText(
        'bitwarden.json',
        '{"encrypted": true, "items": []}',
      );

      await _openImport(robot);
      await robot.tapText('Elegir archivo');

      expect(
        find.textContaining('Este JSON de Bitwarden está cifrado'),
        findsOneWidget,
      );
    });

    testWidgets('cancelar el selector no cambia nada', (tester) async {
      final (_, robot) = await _unlocked(tester);

      await _openImport(robot);
      await robot.tapText('Elegir archivo');

      expect(find.text('Elegir archivo'), findsOneWidget);
      expect(find.textContaining('Se importará'), findsNothing);
    });
  });

  group('Exportar', () {
    testWidgets('guardar el archivo no bloquea la bóveda aunque Android '
        'mande la app a segundo plano', (tester) async {
      final (app, robot) = await _unlocked(tester);
      app.files.whileOpen = () => simulateOtherActivity(tester);

      await _openExport(robot);
      await robot.type('Contraseña maestra', _master);
      await robot.tapButton('Exportar');
      expect(find.text('Exportación lista'), findsOneWidget);
      expect(app.files.saved, hasLength(1));
      await robot.tapText('Entendido');
      expect(find.text('Desbloquear'), findsNothing);
    });

    testWidgets('pide la contraseña maestra: una incorrecta no exporta nada', (
      tester,
    ) async {
      final (app, robot) = await _unlocked(tester);
      await robot.addPassword(title: 'Banco');

      await _openExport(robot);
      await robot.type('Contraseña maestra', 'no es esta');
      await robot.tapButton('Exportar');

      expect(find.text('La contraseña maestra no es correcta'), findsOneWidget);
      expect(app.files.saved, isEmpty);
    });

    testWidgets('un respaldo cifrado se restaura en otro dispositivo con su '
        'contraseña', (tester) async {
      final (phone, robot) = await _unlocked(tester);
      await robot.addPassword(title: 'Banco', username: 'ana');
      await _openExport(robot);
      await robot.type('Contraseña maestra', _master);
      await robot.tapButton('Exportar');
      expect(find.text('Exportación lista'), findsOneWidget);
      final backup = phone.files.saved.single;
      expect(backup.fileName, endsWith('.lockspire'));
      await robot.tapText('Entendido');

      // Otro dispositivo, con otra bóveda, importa el respaldo.
      final laptop = TestApp(crypto: phone.crypto);
      laptop.files.willPick(backup);
      await _unlocked(tester, laptop);
      await _openImport(robot);
      await robot.tapText('Elegir archivo');
      await robot.type('Contraseña', _master);
      await robot.tapText('Abrir');
      expect(find.text('Se importará 1 entrada'), findsOneWidget);
      await robot.tapButton('Importar');
      expect(
        find.text('Se importó 1 entrada desde el respaldo.'),
        findsOneWidget,
      );
    });

    testWidgets('un CSV de Bitwarden pide confirmar que va sin cifrar y '
        'contiene las entradas', (tester) async {
      final (app, robot) = await _unlocked(tester);
      await robot.addPassword(title: 'Banco', username: 'ana', password: 'x1');

      await _openExport(robot);
      await robot.tapText('CSV de Bitwarden');
      await robot.type('Contraseña maestra', _master);
      await robot.tapButton('Exportar');
      expect(find.text('El archivo no va a estar cifrado'), findsOneWidget);
      await robot.tapText('Entiendo, exportar');

      final csv = app.files.saved.single;
      expect(csv.fileName, endsWith('.csv'));
      expect(csv.text, contains('Banco'));
      expect(csv.text, contains('ana'));
      expect(find.textContaining('Recuerde borrarlo'), findsOneWidget);
    });
  });
}
