// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Gabriel Ángel Montoya Rico

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lockspire/features/autofill/domain/ports/autofill_host_port.dart';

import '../support/app_robot.dart';
import '../support/test_app.dart';

const _master = 'correcto caballo batería grapa';

/// Una bóveda con "Banco" (banco.ejemplo), creada en la app normal.
Future<(TestApp, AppRobot)> _withVault(WidgetTester tester) async {
  final app = TestApp(android: true);
  await app.pump(tester);
  final robot = AppRobot(tester);
  await robot.createVault(_master);
  await robot.startNewPassword();
  await robot.type('Título', 'Banco');
  await robot.type('Usuario', 'ana');
  await robot.type('Contraseña', 'Secreta-123');
  await robot.type('Sitio web', 'https://banco.ejemplo');
  await robot.save();
  return (app, robot);
}

/// El autocompletado de Android (ADR 0011, 0020, 0026): el sistema abre
/// Lockspire para rellenar o guardar, y la parte nativa solo ve el
/// resultado.
void main() {
  testWidgets('rellenar: tras desbloquear ofrece la entrada del sitio y la '
      'manda al formulario', (tester) async {
    final (app, robot) = await _withVault(tester);

    await app.pumpAutofill(
      tester,
      const AutofillFillRequest(
        packageName: 'com.android.chrome',
        origin: 'https://banco.ejemplo',
      ),
    );
    await robot.unlock(_master);
    // Marcada como del mismo sitio.
    expect(find.byIcon(Icons.verified_outlined), findsOneWidget);
    await robot.tapText('Banco');

    expect(app.autofillHost.filled, (username: 'ana', password: 'Secreta-123'));
    // Y durante el tiempo del bloqueo, Android ofrece esa cuenta sin volver
    // a pedir desbloqueo (ADR 0026).
    expect(app.autofillHost.sessionItems!.single.title, 'Banco');
  });

  testWidgets('una entrada de otro sitio pide confirmar: puede ser phishing', (
    tester,
  ) async {
    final (app, robot) = await _withVault(tester);

    await app.pumpAutofill(
      tester,
      const AutofillFillRequest(
        packageName: 'com.android.chrome',
        origin: 'https://banco-falso.ejemplo',
      ),
    );
    await robot.unlock(_master);
    await robot.tapText('Banco');

    expect(find.text('¿Es el sitio correcto?'), findsOneWidget);
    await robot.tapText('Cancelar');
    expect(app.autofillHost.filled, isNull);
  });

  testWidgets('guardar: una credencial nueva se guarda con el sitio como '
      'título', (tester) async {
    final (app, robot) = await _withVault(tester);

    await app.pumpAutofill(
      tester,
      const AutofillSaveRequest(
        packageName: 'com.android.chrome',
        origin: 'https://correo.ejemplo',
        username: 'ana@correo.ejemplo',
        password: 'Nueva-456',
      ),
    );
    await robot.unlock(_master);
    expect(find.text('¿Guardar esta credencial en Lockspire?'), findsOneWidget);
    await robot.tapText('Guardar');
    expect(app.autofillHost.saved, isTrue);

    // Está en la bóveda al abrir la app.
    await app.pump(tester);
    await robot.unlock(_master);
    expect(find.text('correo.ejemplo'), findsOneWidget);
  });

  testWidgets('"No, gracias" no guarda nada', (tester) async {
    final (app, robot) = await _withVault(tester);

    await app.pumpAutofill(
      tester,
      const AutofillSaveRequest(
        packageName: 'com.android.chrome',
        origin: 'https://correo.ejemplo',
        username: 'ana',
        password: 'x',
      ),
    );
    await robot.unlock(_master);
    await robot.tapText('No, gracias');

    expect(app.autofillHost.cancelled, isTrue);
    expect(app.autofillHost.saved, isFalse);
  });

  testWidgets('sin bóveda creada, lo dice y permite cerrar', (tester) async {
    final app = TestApp(android: true);
    final robot = AppRobot(tester);

    await app.pumpAutofill(
      tester,
      const AutofillFillRequest(packageName: 'com.app', origin: null),
    );
    expect(
      find.text('Todavía no ha creado una bóveda en Lockspire.'),
      findsOneWidget,
    );
    await robot.tapText('Cerrar');

    expect(app.autofillHost.cancelled, isTrue);
  });

  testWidgets('un pedido que no se entiende se explica', (tester) async {
    final (app, robot) = await _withVault(tester);

    await app.pumpAutofill(tester, const AutofillUnknownRequest());
    await robot.unlock(_master);

    expect(
      find.text('No se pudo entender el pedido de autocompletado.'),
      findsOneWidget,
    );
  });
}
