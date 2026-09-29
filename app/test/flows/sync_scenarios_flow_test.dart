// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Gabriel Ángel Montoya Rico

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/app_robot.dart';
import '../support/fakes/sync_fakes.dart';
import '../support/test_app.dart';

const _master = 'correcto caballo batería grapa';
const _newMaster = 'Otra frase-muy larga 2026!';

/// Teléfono y portátil con la misma bóveda en la misma nube: "Banco" (con
/// usuario "ana") en los dos. Deja abierto el portátil.
class _SyncedDevices {
  final cloud = FakeSyncPort();
  late final phone = TestApp(cloud: cloud);
  late final laptop = TestApp(cloud: cloud, crypto: phone.crypto);
  final AppRobot robot;

  _SyncedDevices(WidgetTester tester) : robot = AppRobot(tester);

  Future<void> setUp(WidgetTester tester) async {
    await phone.pump(tester);
    await robot.createVault(_master);
    await robot.addPassword(title: 'Banco', username: 'ana');
    await robot.openSync();
    await robot.configureWebdav();
    await laptop.pump(tester);
    await robot.restoreFromWebdav(_master);
    expect(find.text('Banco'), findsOneWidget);
  }

  /// "Usa" un dispositivo: lo monta y lo desbloquea.
  Future<void> use(
    WidgetTester tester,
    TestApp device, {
    String? password,
  }) async {
    await device.pump(tester);
    await robot.unlock(password ?? _master);
  }

  Future<void> editUsername(String username) async {
    await robot.tapText('Bóveda');
    await robot.openEntry('Banco');
    await robot.type('Usuario', username);
    await robot.save();
  }

  Future<void> sync() async {
    await robot.openSync();
    await robot.syncNow();
  }
}

/// Situaciones de sync entre dos dispositivos (ADR 0006, 0009, 0018, 0019).
void main() {
  testWidgets('el mismo campo editado en los dos se resuelve solo, y el valor '
      'anterior queda en el historial de la entrada (ADR 0009)', (
    tester,
  ) async {
    final d = _SyncedDevices(tester);
    await d.setUp(tester);

    await d.editUsername('ana.portatil');
    await d.sync();
    // El teléfono edita el mismo campo sin conexión, sin ver el cambio del
    // portátil.
    d.cloud.offline = true;
    await d.use(tester, d.phone);
    await d.editUsername('ana.telefono');
    // Con conexión, la sync (automática o manual) fusiona sin preguntar.
    d.cloud.offline = false;
    await d.sync();

    await d.robot.tapText('Bóveda');
    await d.robot.openEntry('Banco');
    await d.robot.reveal(find.text('Valores anteriores'));
    expect(find.text('Valores anteriores'), findsOneWidget);
    // Gana el cambio más reciente (el del teléfono); el del portátil queda
    // en el historial.
    final username = tester
        .widget<TextField>(d.robot.field('Usuario'))
        .controller!
        .text;
    expect(username, 'ana.telefono');
    await d.robot.tapText('Valores anteriores');
    expect(find.textContaining('ana.portatil'), findsOneWidget);
  });

  testWidgets('si la contraseña maestra cambió en otro dispositivo con la '
      'app abierta, sincronizar lo avisa y permite adoptar la nueva (ADR '
      '0018)', (tester) async {
    final d = _SyncedDevices(tester);
    await d.setUp(tester);

    // El teléfono cambia la contraseña. Para que el cambio "llegue" con el
    // portátil ya abierto, la nube vuelve un momento a la versión anterior.
    final before = d.cloud.remoteFile;
    await d.use(tester, d.phone);
    await d.robot.tapText('Seguridad');
    await d.robot.tapText('Cambiar contraseña maestra');
    await d.robot.type('Contraseña actual', _master);
    await d.robot.type('Contraseña nueva', _newMaster);
    await d.robot.type('Confirmar contraseña nueva', _newMaster);
    await d.robot.tapButton('Cambiar contraseña');
    final changed = d.cloud.remoteFile;
    d.cloud.remoteFile = before;
    await d.use(tester, d.laptop);
    d.cloud.remoteFile = changed;
    await d.sync();

    expect(
      find.text(
        'La contraseña maestra se cambió en otro dispositivo. Ingrese la '
        'nueva para seguir sincronizando.',
      ),
      findsOneWidget,
    );
    await d.robot.tapText('Ingresar contraseña nueva');
    await d.robot.type('Contraseña nueva', 'no es esta');
    await d.robot.tapText('Continuar');
    expect(find.text('No es la contraseña nueva'), findsOneWidget);
    await d.robot.type('Contraseña nueva', _newMaster);
    await d.robot.tapText('Continuar');

    expect(find.textContaining('se cambió en otro dispositivo'), findsNothing);
    // Desde ahora el portátil también abre solo con la nueva.
    await d.robot.lock();
    await d.robot.unlock(_newMaster);
    expect(find.text('Banco'), findsOneWidget);
  });

  testWidgets('una copia vieja restaurada en la nube no pisa lo local: se '
      'pide confirmar antes de reemplazarla (ADR 0019)', (tester) async {
    final d = _SyncedDevices(tester);
    await d.setUp(tester);
    final old = d.cloud.remoteFile;

    await d.editUsername('ana.nueva');
    await d.sync();
    // Alguien vuelve a poner en la nube la copia anterior.
    d.cloud.remoteFile = old;
    await d.robot.syncNow();

    expect(
      find.textContaining('La nube tiene una versión más vieja'),
      findsOneWidget,
    );
    await d.robot.tapText('Subir la versión de este dispositivo');
    expect(find.text('¿Reemplazar la copia de la nube?'), findsOneWidget);
    await d.robot.tapText('Reemplazar');
    expect(d.cloud.remoteFile, isNot(same(old)));
    await d.robot.syncNow();
    expect(find.text('Ya estaba al día — nada que hacer.'), findsOneWidget);
  });

  testWidgets('WebDAV exige https y una URL completa', (tester) async {
    await TestApp(cloud: FakeSyncPort()).pump(tester);
    final robot = AppRobot(tester);
    await robot.createVault(_master);
    await robot.openSync();

    await robot.configureWebdav(url: 'http://nube.ejemplo/dav');
    expect(
      find.text(
        'Use https://: con http:// su usuario y contraseña del servidor '
        'viajarían sin cifrar.',
      ),
      findsOneWidget,
    );

    await robot.configureWebdav(url: 'no es una url');
    expect(
      find.text('Ingrese una URL completa, p. ej. https://servidor/dav'),
      findsOneWidget,
    );
  });
}
