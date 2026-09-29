// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Gabriel Ángel Montoya Rico

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/app_robot.dart';
import '../support/fakes/sync_fakes.dart';
import '../support/test_app.dart';

const _old = 'correcto caballo batería grapa';
const _new = 'Otra frase-muy larga 2026!';

Future<void> _changeMasterPassword(AppRobot robot) async {
  await robot.tapText('Seguridad');
  await robot.tapText('Cambiar contraseña maestra');
  await robot.type('Contraseña actual', _old);
  await robot.type('Contraseña nueva', _new);
  await robot.type('Confirmar contraseña nueva', _new);
  await robot.tester.tap(
    find.widgetWithText(FilledButton, 'Cambiar contraseña'),
  );
  await robot.tester.pumpAndSettle();
}

void main() {
  testWidgets('sin sync: tras cambiar la contraseña maestra, solo la nueva '
      'abre la bóveda', (tester) async {
    await TestApp().pump(tester);
    final robot = AppRobot(tester);
    await robot.createVault(_old);
    await robot.addPassword(title: 'Banco');

    await _changeMasterPassword(robot);
    expect(
      find.text(
        'Contraseña maestra cambiada. Sus otros dispositivos se la pedirán '
        'la próxima vez que sincronicen.',
      ),
      findsOneWidget,
    );

    await robot.lock();
    await robot.unlock(_old);
    expect(find.text('Contraseña incorrecta'), findsOneWidget);
    await robot.unlock(_new);
    expect(find.text('Banco'), findsOneWidget);
  });

  testWidgets('con sync: el otro dispositivo pide la contraseña nueva al '
      'abrir y conserva sus cambios sin sincronizar', (tester) async {
    final cloud = FakeSyncPort();
    final phone = TestApp(cloud: cloud);
    final laptop = TestApp(cloud: cloud, crypto: phone.crypto);
    final robot = AppRobot(tester);

    // Los dos con la misma bóveda.
    await phone.pump(tester);
    await robot.createVault(_old);
    await robot.addPassword(title: 'Banco');
    await robot.openSync();
    await robot.configureWebdav();
    await laptop.pump(tester);
    await robot.tapText('¿Ya tiene una bóveda? Restaurarla desde la nube');
    await robot.tapText('Configurar proveedor de sync');
    await robot.configureWebdav();
    await robot.type('Contraseña maestra', _old);
    await tester.tap(find.widgetWithText(FilledButton, 'Restaurar bóveda'));
    await tester.pumpAndSettle();
    // El portátil agrega algo que todavía no sincroniza.
    await robot.addPassword(title: 'Solo en el portátil');

    // El teléfono cambia la contraseña (se publica en la nube).
    await phone.pump(tester);
    await robot.unlock(_old);
    await _changeMasterPassword(robot);

    // El portátil, al abrir, pide la nueva (ADR 0024), sin huella.
    await laptop.pump(tester);
    expect(
      find.text(
        'La contraseña maestra se cambió en otro dispositivo. Ingrese la '
        'nueva para entrar. Hasta entonces no se puede usar la huella.',
      ),
      findsOneWidget,
    );
    await robot.type('Contraseña maestra nueva', _new);
    await robot.tester.tap(find.widgetWithText(FilledButton, 'Desbloquear'));
    await tester.pumpAndSettle();

    // Tiene cambios sin sincronizar, cifrados con la anterior: la pide
    // también para no perderlos (ADR 0018).
    expect(
      find.text(
        'Este dispositivo tiene cambios que aún no se sincronizaron. Para '
        'conservarlos, ingrese también la contraseña anterior.',
      ),
      findsOneWidget,
    );
    await robot.type('Contraseña anterior', _old);
    await robot.tester.tap(find.widgetWithText(FilledButton, 'Desbloquear'));
    await tester.pumpAndSettle();

    expect(find.text('Banco'), findsOneWidget);
    expect(find.text('Solo en el portátil'), findsOneWidget);
  });
}
