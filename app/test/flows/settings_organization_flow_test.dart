// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Gabriel Ángel Montoya Rico

import 'package:flutter_test/flutter_test.dart';

import '../support/app_robot.dart';
import '../support/test_app.dart';

/// Cómo están organizados Ajustes y Seguridad (revisión de ajustes
/// 2026-09-30): cada opción en su grupo, y Seguridad solo con seguridad.
void main() {
  testWidgets('Ajustes en escritorio: General, Integraciones (Navegador), '
      'Datos y Acerca de', (tester) async {
    await TestApp(desktop: true).pump(tester);
    final robot = AppRobot(tester);
    await robot.createVault('correcto caballo batería grapa');

    await robot.openSettings();

    for (final text in [
      'General',
      'Apariencia',
      'Integraciones',
      'Navegador',
      'Datos',
      'Importar',
      'Exportar',
      'Acerca de',
    ]) {
      expect(find.text(text), findsOneWidget, reason: text);
    }
    expect(find.text('Autocompletado'), findsNothing, reason: 'es de Android');
  });

  testWidgets('Seguridad: contraseña maestra, desbloqueo y bloqueo '
      'automático; ni íconos ni autocompletado', (tester) async {
    await TestApp().pump(tester);
    final robot = AppRobot(tester);
    await robot.createVault('correcto caballo batería grapa');

    await robot.tapText('Seguridad');

    for (final text in [
      'Contraseña maestra',
      'Desbloqueo',
      'Bloqueo automático',
    ]) {
      expect(find.text(text), findsOneWidget, reason: text);
    }
    expect(find.text('Íconos de los sitios'), findsNothing);
    expect(find.text('Activar como autocompletado'), findsNothing);
  });
}
