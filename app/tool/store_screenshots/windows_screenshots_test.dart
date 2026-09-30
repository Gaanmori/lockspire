// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Gabriel Ángel Montoya Rico

// Capturas de Windows para Microsoft Store, con la interfaz real y una
// bóveda de demostración (datos inventados, `demo_vault.json`). No toca
// ninguna bóveda real: corre con los mismos falsos que los tests de flujo.
//
// Desde app/:
//
//   flutter test --update-goldens tool/store_screenshots/windows_screenshots_test.dart
//
// Deja las imágenes en docs/store/assets/screenshots/windows/. No corre en
// `flutter test` normal (está fuera de test/).

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lockspire/main.dart';
import 'package:path/path.dart' as p;

import 'package:lockspire/features/vault/domain/ports/biometric_auth_port.dart';

import '../../test/support/app_robot.dart';
import '../../test/support/fakes/vault_fakes.dart';
import '../../test/support/test_app.dart';

/// 1920 × 1080 a 125 %: una pantalla Full HD con la escala habitual de
/// Windows.
const _size = Size(1920, 1080);
const _pixelRatio = 1.25;
const _out = '../../../docs/store/assets/screenshots/windows';
const _master = 'demo-capturas-lockspire';

Future<void> _loadFont(String family, List<String> files) async {
  final loader = FontLoader(family);
  for (final file in files) {
    loader.addFont(
      Future.value(ByteData.sublistView(File(file).readAsBytesSync())),
    );
  }
  await loader.load();
}

/// Las fuentes de verdad: sin esto, los tests dibujan cada letra como un
/// rectángulo.
Future<void> _loadFonts() async {
  final flutterRoot = Platform.environment['FLUTTER_ROOT']!;
  final material = p.join(
    flutterRoot,
    'bin',
    'cache',
    'artifacts',
    'material_fonts',
  );
  await _loadFont('Quicksand', ['assets/fonts/Quicksand[wght].ttf']);
  await _loadFont('Karla', ['assets/fonts/Karla[wght].ttf']);
  await _loadFont('MaterialIcons', [
    p.join(material, 'materialicons-regular.otf'),
  ]);
  await _loadFont('Roboto', [
    p.join(material, 'roboto-regular.ttf'),
    p.join(material, 'roboto-medium.ttf'),
    p.join(material, 'roboto-bold.ttf'),
  ]);
}

Future<void> _shot(WidgetTester tester, String name) async {
  // Sin foco de teclado a la vista: con el ratón no se ve.
  FocusManager.instance.primaryFocus?.unfocus();
  // Los tests dibujan las sombras como un contorno negro; para la captura,
  // como en la app. El framework exige dejarlo como estaba.
  debugDisableShadows = false;
  try {
    for (final view in tester.binding.renderViews) {
      view.markNeedsPaint();
    }
    await tester.pumpAndSettle();
    await expectLater(find.byType(MyApp), matchesGoldenFile('$_out/$name.png'));
  } finally {
    debugDisableShadows = true;
  }
}

/// Una app de escritorio con la bóveda de demostración ya importada, y
/// Windows Hello disponible pero sin activar.
Future<(TestApp, AppRobot)> _demo(WidgetTester tester) async {
  final app = TestApp(
    desktop: true,
    biometric: FakeBiometricAuthPort()
      ..available = BiometricAvailability.available,
  );
  await app.pump(tester, size: _size, pixelRatio: _pixelRatio);
  final robot = AppRobot(tester);
  await robot.createVault(_master);
  if (find.text('Ahora no').evaluate().isNotEmpty) {
    await robot.tapText('Ahora no');
  }
  app.files.willPickText(
    'lockspire-demo.json',
    File('tool/store_screenshots/demo_vault.json').readAsStringSync(),
  );
  await robot.openSettings();
  await robot.tapText('Importar');
  await robot.tapText('Elegir archivo');
  await robot.tapButton('Importar');
  await robot.tapText('Entendido');
  await robot.systemBack();
  await robot.tapText('Bóveda');
  return (app, robot);
}

void main() {
  setUpAll(() async {
    await _loadFonts();
    // El cartel "DEBUG" solo existe en los builds de depuración.
    WidgetsApp.debugAllowBannerOverride = false;
    // Como con el ratón: sin anillos de foco de teclado.
    FocusManager.instance.highlightStrategy =
        FocusHighlightStrategy.alwaysTouch;
  });

  testWidgets('01 la bóveda', (tester) async {
    await _demo(tester);
    await _shot(tester, 'es-01-boveda');
  });

  testWidgets('02 una entrada con el generador', (tester) async {
    final (_, robot) = await _demo(tester);
    await robot.openEntry('Banco del Parque');
    await _shot(tester, 'es-02-entrada');
  });

  testWidgets('03 seguridad: Windows Hello y bloqueo automático', (
    tester,
  ) async {
    final (_, robot) = await _demo(tester);
    await robot.tapText('Seguridad');
    await _shot(tester, 'es-03-seguridad');
  });

  testWidgets('04 temas', (tester) async {
    final (_, robot) = await _demo(tester);
    await robot.openSettings();
    await robot.tapText('Apariencia');
    await _shot(tester, 'es-04-temas');
  });

  testWidgets('05 perfiles: varias bóvedas en el mismo equipo', (tester) async {
    final (_, robot) = await _demo(tester);
    await robot.openSettings();
    await robot.tapText('Perfiles');
    await robot.tapText('Cambiar nombre');
    await tester.enterText(find.byType(TextField).last, 'Ana');
    await robot.tapButton('Guardar');
    await robot.tapText('Agregar perfil');
    await tester.enterText(find.byType(TextField).last, 'Luis');
    await robot.tapButton('Agregar');
    await robot.waitFor(find.text('Crear bóveda').last);
    await robot.createVault('otra-demo-de-luis');
    await robot.lock();
    await tester.tap(find.widgetWithText(ChoiceChip, 'Ana'));
    await robot.waitFor(find.text('Desbloquear').last);
    await _shot(tester, 'es-05-perfiles');
  });

  testWidgets('06 modo oscuro', (tester) async {
    final (_, robot) = await _demo(tester);
    await robot.openSettings();
    await robot.tapText('Apariencia');
    // El selector de modo, no la vista previa "Oscuro" de un tema.
    await tester.tap(find.text('Oscuro').first);
    await robot.settle();
    await robot.systemBack();
    await robot.tapText('Bóveda');
    await robot.openEntry('Correo personal');
    await _shot(tester, 'es-06-oscuro');
  });
}
