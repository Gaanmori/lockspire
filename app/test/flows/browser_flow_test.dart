// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Gabriel Ángel Montoya Rico

import 'package:flutter_test/flutter_test.dart';
import 'package:lockspire/features/browser_bridge/application/handle_bridge_request.dart';
import 'package:lockspire/features/browser_bridge/domain/ports/native_messaging_registration_port.dart';
import 'package:lockspire/features/browser_bridge/presentation/providers/pending_link_request_provider.dart';
import 'package:lockspire/features/vault/presentation/vault_session_controller.dart';
import 'package:lockspire/features/vault/presentation/vault_session_state.dart';

import '../support/app_robot.dart';
import '../support/test_app.dart';

const _master = 'correcto caballo batería grapa';

Future<(TestApp, AppRobot)> _desktopUnlocked(WidgetTester tester) async {
  final app = TestApp(desktop: true);
  await app.pump(tester);
  final robot = AppRobot(tester);
  await robot.createVault(_master);
  return (app, robot);
}

Future<void> _openBrowser(AppRobot robot) async {
  await robot.openSettings();
  await robot.tapText('Navegador');
}

/// La extensión de Chrome/Edge (ADR 0013, 0014, 0015) vista desde la app.
void main() {
  group('Conectar con el navegador', () {
    testWidgets('conectar registra el host en los navegadores instalados y '
        'desconectar lo quita', (tester) async {
      final (app, robot) = await _desktopUnlocked(tester);
      await _openBrowser(robot);
      expect(find.text('No conectado con ningún navegador'), findsOneWidget);
      expect(
        find.text('Lockspire está escuchando a la extensión.'),
        findsOneWidget,
      );

      await robot.tapText('Conectar con Chrome/Edge');
      expect(
        find.text('Listo. Reinicie el navegador si ya estaba abierto.'),
        findsOneWidget,
      );
      expect(
        find.text('Conectado con Google Chrome, Microsoft Edge'),
        findsOneWidget,
      );

      await robot.tapText('Desconectar');
      expect(app.nativeMessaging.registeredIn, isEmpty);
      expect(find.text('No conectado con ningún navegador'), findsOneWidget);
    });

    testWidgets('sin navegadores compatibles lo dice en vez de "listo"', (
      tester,
    ) async {
      final (app, robot) = await _desktopUnlocked(tester);
      app.nativeMessaging.installed = {};
      await _openBrowser(robot);

      await robot.tapText('Conectar con Chrome/Edge');

      expect(
        find.text('No se encontró ningún navegador compatible.'),
        findsOneWidget,
      );
    });

    testWidgets('sin el componente del host junto a la app, lo avisa', (
      tester,
    ) async {
      final (app, robot) = await _desktopUnlocked(tester);
      app.nativeMessaging.hostBinaryFound = false;
      await _openBrowser(robot);

      expect(
        find.textContaining('Falta el componente "lockspire-native-host"'),
        findsOneWidget,
      );
    });

    testWidgets('registrar para todo el equipo, y si se cancela el permiso de '
        'administrador lo explica (ADR 0014)', (tester) async {
      final (app, robot) = await _desktopUnlocked(tester);
      await _openBrowser(robot);

      app.nativeMessaging.cancelElevation = true;
      await robot.tapText('Registrar para todo el equipo');
      expect(
        find.textContaining('se canceló el permiso de administrador'),
        findsOneWidget,
      );

      app.nativeMessaging.cancelElevation = false;
      await robot.tapText('Registrar para todo el equipo');
      expect(find.text('Registrado para todo el equipo'), findsOneWidget);
      expect(
        app.nativeMessaging.registeredSystemWideIn,
        contains(SupportedBrowser.chrome),
      );
    });
  });

  group('Vincular un sitio pedido por la extensión (ADR 0015)', () {
    Future<(TestApp, AppRobot)> withLinkRequest(WidgetTester tester) async {
      final (app, robot) = await _desktopUnlocked(tester);
      await robot.addPassword(title: 'Banco');
      final session =
          app.container.read(vaultSessionControllerProvider).value!
              as VaultSessionUnlocked;
      final entry = session.vault.entries.firstWhere((e) => e.title == 'Banco');
      app.container
          .read(pendingLinkRequestProvider.notifier)
          .set(
            LinkRequest(
              entryId: entry.id,
              entryTitle: entry.title,
              currentUrl: '',
              newUrl: 'https://banco.ejemplo',
            ),
          );
      await robot.settle();
      return (app, robot);
    }

    testWidgets('confirmar guarda el sitio en la entrada', (tester) async {
      final (_, robot) = await withLinkRequest(tester);
      expect(find.text('¿Vincular este sitio?'), findsOneWidget);
      expect(find.text('La entrada no tenía ninguna URL.'), findsOneWidget);

      await robot.tapButton('Vincular');

      expect(
        find.textContaining('"Banco" vinculada a banco.ejemplo'),
        findsOneWidget,
      );
      await robot.openEntry('Banco');
      expect(find.text('https://banco.ejemplo'), findsOneWidget);
    });

    testWidgets('cancelar no cambia la entrada', (tester) async {
      final (_, robot) = await withLinkRequest(tester);

      await robot.tapText('Cancelar');

      await robot.openEntry('Banco');
      expect(find.text('https://banco.ejemplo'), findsNothing);
    });
  });
}
