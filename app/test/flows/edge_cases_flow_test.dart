// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Gabriel Ángel Montoya Rico

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/app_robot.dart';
import '../support/fakes/sync_fakes.dart';
import '../support/test_app.dart';

const _master = 'correcto caballo batería grapa';

/// Exportado de SafeInCloud con una tarjeta y un pasaporte que traen
/// valores anteriores (atributo `history`).
const _safeInCloudXml = '''
<?xml version="1.0" encoding="utf-8"?>
<database>
  <card title="Visa" id="1" first_stamp="1669000000000" time_stamp="1669000000001">
    <field name="Número" type="number" autofill="cc-number" history="{&quot;1669100000000&quot;:&quot;4000 0000 0000 0001&quot;}">4111 1111 1111 1111</field>
    <field name="Titular" type="text" autofill="cc-name" history="{&quot;1669100000000&quot;:&quot;ANA P&quot;}">ANA PEREZ</field>
    <field name="Vence" type="expiry" autofill="cc-exp" history="{&quot;1669100000000&quot;:&quot;01/26&quot;}">09/29</field>
    <field name="CVV" type="pin" autofill="cc-csc" history="{&quot;1669100000000&quot;:&quot;999&quot;}">123</field>
  </card>
  <card title="Pasaporte" id="2" symbol="passport" first_stamp="1669000000000" time_stamp="1669000000001">
    <field name="Número" type="number" history="{&quot;1669100000000&quot;:&quot;AA000&quot;}">AB123</field>
    <field name="Nombre" type="text" history="{&quot;1669100000000&quot;:&quot;Ana&quot;}">Ana Pérez</field>
    <field name="Vence" type="expiry">01/01/2030</field>
  </card>
</database>
''';

Future<(TestApp, AppRobot)> _unlocked(WidgetTester tester) async {
  final app = TestApp();
  await app.pump(tester);
  final robot = AppRobot(tester);
  await robot.createVault(_master);
  return (app, robot);
}

/// Casos de borde que el usuario puede encontrarse.
void main() {
  testWidgets('importar de SafeInCloud una tarjeta y un documento: el resumen '
      'los cuenta y el historial muestra cada campo con su nombre', (
    tester,
  ) async {
    final (app, robot) = await _unlocked(tester);
    app.files.willPickText('SafeInCloud.xml', _safeInCloudXml);

    await robot.openSettings();
    await robot.tapText('Importar');
    await robot.tapText('Elegir archivo');
    expect(find.text('1 tarjeta y 1 documento'), findsOneWidget);
    await robot.tapButton('Importar');
    await robot.tapText('Entendido');

    await robot.tapText('Bóveda');
    await robot.openEntry('Visa');
    await robot.reveal(find.text('Valores anteriores'));
    await robot.tapText('Valores anteriores');
    for (final name in ['Número de tarjeta', 'Titular', 'Vence', 'CVV']) {
      expect(find.text(name), findsWidgets, reason: name);
    }
    // Lo secreto del historial no se muestra en claro.
    expect(find.textContaining('999'), findsNothing);
    expect(find.textContaining('ANA P —'), findsOneWidget);
  });

  testWidgets('cancelar la contraseña de un respaldo no importa nada', (
    tester,
  ) async {
    final (app, robot) = await _unlocked(tester);
    app.files.willPickText('respaldo.lockspire', 'no importa');

    await robot.openSettings();
    await robot.tapText('Importar');
    await robot.tapText('Elegir archivo');
    expect(find.text('Contraseña del respaldo'), findsOneWidget);
    await robot.tapText('Cancelar');

    expect(find.text('Elegir archivo'), findsOneWidget);
    expect(find.textContaining('Se importará'), findsNothing);
    expect(find.textContaining('No se pudo'), findsNothing);
  });

  testWidgets('desbloquear sin escribir nada pide la contraseña', (
    tester,
  ) async {
    final (_, robot) = await _unlocked(tester);
    await robot.lock();

    await robot.tapButton('Desbloquear');

    expect(find.text('Ingrese su contraseña maestra'), findsOneWidget);
  });

  testWidgets('el ojo del campo de contraseña la muestra y la oculta', (
    tester,
  ) async {
    final (_, robot) = await _unlocked(tester);
    await robot.lock();
    bool obscured() =>
        tester.widget<TextField>(robot.field('Contraseña maestra')).obscureText;

    expect(obscured(), isTrue);
    await tester.tap(find.byIcon(Icons.visibility));
    await tester.pump();
    expect(obscured(), isFalse);
  });

  testWidgets('con la contraseña cambiada en otro dispositivo, "No tengo la '
      'contraseña nueva" permite abrir con la anterior (ADR 0024)', (
    tester,
  ) async {
    final cloud = FakeSyncPort();
    final phone = TestApp(cloud: cloud);
    await phone.pump(tester);
    final robot = AppRobot(tester);
    await robot.createVault(_master);
    await robot.addPassword(title: 'Banco');
    await robot.openSync();
    await robot.configureWebdav();
    final laptop = TestApp(cloud: cloud, crypto: phone.crypto);
    await laptop.pump(tester);
    await robot.restoreFromWebdav(_master);
    await phone.pump(tester);
    await robot.unlock(_master);
    await robot.tapText('Seguridad');
    await robot.tapText('Cambiar contraseña maestra');
    await robot.type('Contraseña actual', _master);
    await robot.type('Contraseña nueva', 'Otra frase-muy larga 2026!');
    await robot.type(
      'Confirmar contraseña nueva',
      'Otra frase-muy larga 2026!',
    );
    await robot.tapButton('Cambiar contraseña');

    await laptop.pump(tester);
    expect(find.text('Contraseña maestra nueva'), findsOneWidget);
    await robot.tapText('No tengo la contraseña nueva');
    await robot.unlock(_master);

    expect(find.text('Banco'), findsOneWidget);
  });

  testWidgets('si no se puede leer la bóveda al abrir, lo dice y permite '
      'reintentar', (tester) async {
    final app = TestApp();
    app.storage.existsError = const FileSystemException('disco ilegible');
    await app.pump(tester);
    final robot = AppRobot(tester);

    expect(find.textContaining('Ocurrió un error'), findsOneWidget);
    app.storage.existsError = null;
    await robot.tapText('Reintentar');

    expect(find.text('Cree su bóveda'), findsOneWidget);
  });
}
