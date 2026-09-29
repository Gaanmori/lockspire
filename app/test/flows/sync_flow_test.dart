// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Gabriel Ángel Montoya Rico

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/app_robot.dart';
import '../support/fakes/sync_fakes.dart';
import '../support/test_app.dart';

const _master = 'correcto caballo batería grapa';

/// Dos dispositivos con la misma nube. En un test de widgets hay una sola
/// pantalla: "usar un dispositivo" es montarlo (con su propia bóveda,
/// almacenamiento seguro y ancestro) y desbloquearlo.
class _Devices {
  final cloud = FakeSyncPort();
  late final phone = TestApp(cloud: cloud);
  late final laptop = TestApp(cloud: cloud, crypto: phone.crypto);
}

void main() {
  testWidgets('una bóveda creada en un dispositivo se restaura en otro, y '
      'los cambios de cada uno llegan al otro al sincronizar', (tester) async {
    final devices = _Devices();
    final robot = AppRobot(tester);

    // Teléfono: crea la bóveda, agrega una entrada y conecta WebDAV.
    await devices.phone.pump(tester);
    await robot.createVault(_master);
    await robot.addPassword(title: 'Banco');
    await robot.openSync();
    await robot.configureWebdav();
    // Conectar la nube ya sube la bóveda (ADR 0023): sincronizar enseguida
    // no tiene nada que hacer.
    expect(devices.cloud.remoteFile, isNotNull);
    await robot.syncNow();
    expect(find.text('Ya estaba al día — nada que hacer.'), findsOneWidget);

    // Portátil: restaura desde la nube.
    await devices.laptop.pump(tester);
    await robot.tapText('¿Ya tiene una bóveda? Restaurarla desde la nube');
    await robot.tapText('Configurar proveedor de sync');
    // Al guardar vuelve sola a Restaurar y busca la bóveda.
    await robot.configureWebdav();
    expect(find.text('Encontramos su bóveda'), findsOneWidget);
    await robot.type('Contraseña maestra', _master);
    await tester.tap(find.widgetWithText(FilledButton, 'Restaurar bóveda'));
    await tester.pumpAndSettle();
    expect(find.text('Banco'), findsOneWidget);

    // Portátil: agrega otra y sincroniza.
    await robot.addPassword(title: 'Correo');
    await robot.openSync();
    await robot.syncNow();

    // Teléfono: al sincronizar recibe la del portátil.
    await devices.phone.pump(tester);
    await robot.unlock(_master);
    await robot.openSync();
    await robot.syncNow();
    await robot.tapText('Bóveda');
    expect(find.text('Banco'), findsOneWidget);
    expect(find.text('Correo'), findsOneWidget);
  });
}
