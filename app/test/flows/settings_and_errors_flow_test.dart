// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Gabriel Ángel Montoya Rico

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lockspire/features/autofill/domain/ports/autofill_host_port.dart';

import '../support/app_robot.dart';
import '../support/fakes/sync_fakes.dart';
import '../support/test_app.dart';

const _master = 'correcto caballo batería grapa';
const _new = 'Otra frase-muy larga 2026!';

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
  group('Bloqueo automático (ADR 0016)', () {
    // Regresión (2026-09-29, encontrada por este test): el arranque dejaba
    // en pausa al controlador de bloqueo y el cambio no le llegaba; seguía
    // bloqueando a los 5 minutos.
    testWidgets('con 1 minuto se bloquea al minuto sin uso', (tester) async {
      final (_, robot) = await _unlocked(tester);
      await robot.tapText('Seguridad');
      await robot.tapText('1 min');

      await tester.pump(const Duration(seconds: 70));
      await robot.settle();

      expect(find.text('¡Hola de nuevo!'), findsOneWidget);
    });

    testWidgets('con 15 minutos avisa que la bóveda queda abierta más tiempo', (
      tester,
    ) async {
      final (_, robot) = await _unlocked(tester);
      await robot.tapText('Seguridad');

      await robot.tapText('15 min');

      expect(find.textContaining('queda abierta más tiempo'), findsOneWidget);
    });
  });

  group('Selección en la lista', () {
    testWidgets('un toque largo selecciona; cancelar el borrado no borra', (
      tester,
    ) async {
      final (_, robot) = await _unlocked(tester);
      await robot.addPassword(title: 'Banco');
      await robot.addPassword(title: 'Correo');

      await tester.longPress(find.text('Banco'));
      await robot.settle();
      expect(find.text('1 seleccionada'), findsOneWidget);
      await robot.tapText('Correo');
      expect(find.text('2 seleccionadas'), findsOneWidget);
      await robot.tapText('Correo');
      expect(find.text('1 seleccionada'), findsOneWidget);

      await robot.tapTooltip('Eliminar seleccionadas');
      await robot.tapText('Cancelar');
      expect(find.text('Banco'), findsOneWidget);

      await robot.tapTooltip('Cancelar selección');
      expect(find.text('1 seleccionada'), findsNothing);
    });
  });

  testWidgets('quitar el registro para todo el equipo', (tester) async {
    final (app, robot) = await _unlocked(tester, TestApp(desktop: true));
    await robot.openSettings();
    await robot.tapText('Navegador');
    await robot.tapText('Registrar para todo el equipo');
    // El aviso de "listo" tiene que irse antes de que se vea el siguiente.
    await tester.pump(const Duration(seconds: 5));
    await robot.settle();

    await robot.tapText('Quitar registro');

    expect(
      find.text('Se quitó el registro para todo el equipo.'),
      findsOneWidget,
    );
    expect(app.nativeMessaging.registeredSystemWideIn, isEmpty);
  });

  testWidgets('contraseña cambiada en otro dispositivo: la nueva equivocada y '
      'la anterior equivocada se distinguen', (tester) async {
    final cloud = FakeSyncPort();
    final phone = TestApp(cloud: cloud);
    await phone.pump(tester);
    final robot = AppRobot(tester);
    await robot.createVault(_master);
    await robot.openSync();
    await robot.configureWebdav();
    final laptop = TestApp(cloud: cloud, crypto: phone.crypto);
    await laptop.pump(tester);
    await robot.restoreFromWebdav(_master);
    await robot.addPassword(title: 'Solo en el portátil');
    // Sin conexión, el cambio del portátil queda sin sincronizar.
    cloud.offline = true;
    await robot.addPassword(title: 'Otra sin subir');
    cloud.offline = false;
    await phone.pump(tester);
    await robot.unlock(_master);
    await robot.tapText('Seguridad');
    await robot.tapText('Cambiar contraseña maestra');
    await robot.type('Contraseña actual', _master);
    await robot.type('Contraseña nueva', _new);
    await robot.type('Confirmar contraseña nueva', _new);
    await robot.tapButton('Cambiar contraseña');
    await laptop.pump(tester);

    await robot.type('Contraseña maestra nueva', 'no es esta');
    await robot.tapButton('Desbloquear');
    expect(find.text('No es la contraseña nueva'), findsOneWidget);

    await robot.type('Contraseña maestra nueva', _new);
    await robot.tapButton('Desbloquear');
    await robot.type('Contraseña anterior', 'tampoco');
    await robot.tapButton('Desbloquear');
    expect(find.text('La contraseña anterior no es correcta'), findsOneWidget);
  });

  testWidgets('el autocompletado explica si no puede leer la bóveda', (
    tester,
  ) async {
    final app = TestApp(android: true);
    app.storage.existsError = const FileSystemException('disco ilegible');

    await app.pumpAutofill(
      tester,
      const AutofillFillRequest(packageName: 'com.app', origin: null),
    );

    expect(find.textContaining('Ocurrió un error'), findsOneWidget);
  });
}
