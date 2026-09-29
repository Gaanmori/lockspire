// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Gabriel Ángel Montoya Rico

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lockspire/features/vault/domain/ports/biometric_auth_port.dart';

import '../support/app_robot.dart';
import '../support/fakes/vault_fakes.dart';
import '../support/test_app.dart';

const _master = 'correcto caballo batería grapa';

/// Una app con huella disponible y aceptada por defecto.
TestApp _withFingerprint() => TestApp(
  biometric: FakeBiometricAuthPort()
    ..available = BiometricAvailability.available
    ..fingerAccepted = true,
);

/// Crea la bóveda, bloquea y desbloquea con contraseña: ahí se ofrece
/// activar la huella.
Future<AppRobot> _firstPasswordUnlock(WidgetTester tester, TestApp app) async {
  await app.pump(tester);
  final robot = AppRobot(tester);
  await robot.createVault(_master);
  await robot.addPassword(title: 'Banco');
  await robot.lock();
  await robot.unlock(_master);
  return robot;
}

/// Desbloqueo con huella (ADR 0010, 0017).
void main() {
  testWidgets('tras desbloquear con contraseña se ofrece activar la huella; '
      'activada, desbloquea sin escribir la contraseña', (tester) async {
    final app = _withFingerprint();
    final robot = await _firstPasswordUnlock(tester, app);

    expect(find.text('¿Activar desbloqueo con la huella?'), findsOneWidget);
    await robot.tapText('Activar');

    await robot.lock();
    await robot.tapText('Usar la huella');
    expect(find.text('Banco'), findsOneWidget);
  });

  testWidgets('una huella rechazada deja la pantalla de contraseña, sin '
      'error', (tester) async {
    final app = _withFingerprint();
    final robot = await _firstPasswordUnlock(tester, app);
    await robot.tapText('Activar');
    await robot.lock();

    app.biometric.fingerAccepted = false;
    await robot.tapText('Usar la huella');

    expect(find.text('Banco'), findsNothing);
    expect(find.text('¡Hola de nuevo!'), findsOneWidget);
    expect(find.text('Contraseña incorrecta'), findsNothing);
  });

  testWidgets('"Ahora no" no lo vuelve a preguntar', (tester) async {
    final app = _withFingerprint();
    final robot = await _firstPasswordUnlock(tester, app);

    await robot.tapText('Ahora no');
    await robot.lock();
    await robot.unlock(_master);

    expect(find.text('¿Activar desbloqueo con la huella?'), findsNothing);
    expect(find.text('Usar la huella'), findsNothing);
  });

  testWidgets('en Seguridad se desactiva la huella y se elige cada cuánto '
      'pedir la contraseña', (tester) async {
    final app = _withFingerprint();
    final robot = await _firstPasswordUnlock(tester, app);
    await robot.tapText('Activar');

    await robot.tapText('Seguridad');
    expect(
      tester.widget<SwitchListTile>(find.byType(SwitchListTile).first).value,
      isTrue,
    );
    await robot.tapText('Desbloquear con la huella');
    expect(await app.biometric.hasStoredKey(), isFalse);

    await robot.reveal(find.text('30 días'));
    await robot.tapText('30 días');
    expect(
      tester
          .widget<SegmentedButton<Object?>>(find.byType(SegmentedButton).first)
          .selected
          .single
          .toString(),
      contains('thirty'),
    );
  });

  testWidgets('sin huella configurada en el sistema, Seguridad explica cómo '
      'activarla', (tester) async {
    final app = TestApp(
      biometric: FakeBiometricAuthPort()
        ..available = BiometricAvailability.notEnrolled,
    );
    await app.pump(tester);
    final robot = AppRobot(tester);
    await robot.createVault(_master);

    await robot.tapText('Seguridad');

    expect(
      find.text(
        'Configure la huella en los ajustes del sistema para poder activarlo '
        'aquí.',
      ),
      findsOneWidget,
    );
  });
}
