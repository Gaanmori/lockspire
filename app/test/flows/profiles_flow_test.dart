// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Gabriel Ángel Montoya Rico

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lockspire/features/appearance/domain/appearance_preference.dart';
import 'package:lockspire/features/appearance/presentation/appearance_controller.dart';
import 'package:lockspire/features/profiles/domain/profile.dart';
import 'package:lockspire/shared/secure_storage_provider.dart';

import '../support/app_robot.dart';
import '../support/test_app.dart';

const _mine = 'correcto caballo batería grapa';
const _hers = 'otra frase larga de María';

Finder _chip(String name) => find.widgetWithText(ChoiceChip, name);

Future<void> _openProfiles(AppRobot robot) async {
  await robot.openSettings();
  await robot.tapText('Perfiles');
}

/// Agrega un perfil desde Ajustes y espera a que se abra (vacío).
Future<void> _addProfile(AppRobot robot, String name) async {
  await robot.tapText('Agregar perfil');
  await robot.tester.enterText(find.byType(TextField).last, name);
  await robot.tapButton('Agregar');
  await robot.waitFor(find.text('Crear bóveda').last);
}

/// Varias bóvedas en el mismo equipo (ADR 0039).
void main() {
  testWidgets('con un solo perfil, desbloquear se ve como siempre', (
    tester,
  ) async {
    final app = TestApp(desktop: true);
    await app.pump(tester);
    final robot = AppRobot(tester);
    await robot.createVault(_mine);
    await robot.lock();

    expect(find.byType(ChoiceChip), findsNothing);
    expect(find.text('Agregar perfil'), findsNothing);
  });

  testWidgets('cada perfil tiene su propia bóveda y su contraseña: '
      'la de uno no abre la del otro', (tester) async {
    final app = TestApp(desktop: true);
    await app.pump(tester);
    final robot = AppRobot(tester);
    await robot.createVault(_mine);
    await robot.addPassword(title: 'Mi banco');

    await _openProfiles(robot);
    await _addProfile(robot, 'María');
    expect(app.container.read(activeProfileIdProvider), isNot(mainProfileId));
    expect(_chip('María'), findsOneWidget);
    expect(_chip('Principal'), findsOneWidget);

    await robot.createVault(_hers);
    expect(find.text('Mi banco'), findsNothing);
    await robot.addPassword(title: 'Banco de María');
    await robot.lock();

    // Su contraseña no abre la bóveda del principal.
    await tester.tap(_chip('Principal'));
    await robot.waitFor(find.text('Desbloquear').last);
    expect(app.container.read(activeProfileIdProvider), mainProfileId);
    await robot.unlock(_hers);
    expect(find.text('Contraseña incorrecta'), findsOneWidget);
    await robot.unlock(_mine);
    expect(find.text('Mi banco'), findsOneWidget);
    expect(find.text('Banco de María'), findsNothing);
  });

  testWidgets('cambiar de perfil bloquea y no deja nada del anterior '
      'abierto', (tester) async {
    final app = TestApp(desktop: true);
    await app.pump(tester);
    final robot = AppRobot(tester);
    await robot.createVault(_mine);
    await _openProfiles(robot);
    await _addProfile(robot, 'Demo');
    await robot.createVault(_hers);

    await _openProfiles(robot);
    await robot.tapText('Abrir');
    await robot.waitFor(find.text('Desbloquear').last);

    expect(find.text('Mi banco'), findsNothing);
    expect(app.container.read(activeProfileIdProvider), mainProfileId);
  });

  testWidgets('el tema es de cada perfil', (tester) async {
    final app = TestApp(desktop: true);
    await app.pump(tester);
    final robot = AppRobot(tester);
    await robot.createVault(_mine);
    await _openProfiles(robot);
    await _addProfile(robot, 'María');
    await robot.createVault(_hers);

    await robot.openSettings();
    await robot.tapText('Apariencia');
    await robot.reveal(find.text('Pixel'));
    await robot.tapText('Pixel');
    expect(
      app.container.read(appearanceControllerProvider).value!.family,
      ThemeFamilyId.pixel,
    );

    await robot.systemBack();
    await robot.lock();
    await tester.tap(_chip('Principal'));
    await robot.waitFor(find.text('Desbloquear').last);
    expect(
      app.container.read(appearanceControllerProvider).value!.family,
      ThemeFamilyId.grafito,
    );
  });

  testWidgets('el nombre no puede estar vacío ni repetirse; el error se '
      'muestra sin cerrar el diálogo', (tester) async {
    final app = TestApp(desktop: true);
    await app.pump(tester);
    final robot = AppRobot(tester);
    await robot.createVault(_mine);
    await _openProfiles(robot);

    await robot.tapText('Agregar perfil');
    await robot.tapButton('Agregar');
    expect(find.text('Escriba un nombre para el perfil.'), findsOneWidget);

    await tester.enterText(find.byType(TextField).last, 'principal');
    await robot.tapButton('Agregar');
    expect(find.text('Ya hay un perfil con ese nombre.'), findsOneWidget);
    expect(app.container.read(activeProfileIdProvider), mainProfileId);
  });

  testWidgets('cambiar el nombre del perfil abierto', (tester) async {
    final app = TestApp(desktop: true);
    await app.pump(tester);
    final robot = AppRobot(tester);
    await robot.createVault(_mine);
    await _openProfiles(robot);

    await robot.tapText('Cambiar nombre');
    await tester.enterText(find.byType(TextField).last, 'Gabriel');
    await robot.tapButton('Guardar');

    expect(find.text('Gabriel'), findsOneWidget);
  });

  testWidgets('borrar un perfil exige tenerlo abierto, vuelve al principal '
      'y borra sus datos; el principal no se puede borrar', (tester) async {
    final app = TestApp(desktop: true);
    await app.pump(tester);
    final robot = AppRobot(tester);
    await robot.createVault(_mine);
    await _openProfiles(robot);
    expect(find.text('Eliminar este perfil'), findsNothing);

    await _addProfile(robot, 'Demo');
    final demoId = app.container.read(activeProfileIdProvider);
    await robot.createVault(_hers);
    await _openProfiles(robot);
    await robot.tapText('Eliminar este perfil');
    expect(find.text('¿Eliminar el perfil Demo?'), findsOneWidget);
    await robot.tapButton('Eliminar');
    await robot.waitFor(find.text('Desbloquear').last);

    expect(app.profileData.erased, [demoId]);
    expect(app.container.read(activeProfileIdProvider), mainProfileId);
    // Con un solo perfil, la lista ya no se muestra.
    expect(find.byType(ChoiceChip), findsNothing);
  });

  group('Android', () {
    testWidgets('vienen desactivados; activarlos permite agregar, y no se '
        'desactivan con más de uno', (tester) async {
      final app = TestApp(android: true);
      await app.pump(tester);
      final robot = AppRobot(tester);
      await robot.createVault(_mine);
      await _openProfiles(robot);

      expect(find.text('Agregar perfil'), findsNothing);
      await robot.tapText('Usar varios perfiles');
      expect(find.text('Agregar perfil'), findsOneWidget);

      await _addProfile(robot, 'Demo');
      await robot.createVault(_hers);
      await _openProfiles(robot);
      await robot.tapText('Usar varios perfiles');
      expect(
        find.text(
          'Para desactivar los perfiles, primero borre los demás: solo '
          'puede quedar uno.',
        ),
        findsOneWidget,
      );
    });
  });
}
