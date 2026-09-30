// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Gabriel Ángel Montoya Rico

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:lockspire/features/browser_bridge/application/handle_bridge_request.dart';
import 'package:lockspire/features/browser_bridge/domain/ports/native_messaging_registration_port.dart';
import 'package:lockspire/features/browser_bridge/presentation/providers/browser_bridge_provider.dart';
import 'package:lockspire/features/browser_bridge/presentation/providers/browser_login_providers.dart';
import 'package:lockspire/features/browser_bridge/presentation/providers/pending_link_request_provider.dart';
import 'package:lockspire/features/vault/presentation/vault_session_controller.dart';
import 'package:lockspire/features/vault/domain/entities/vault_entry.dart';
import 'package:lockspire/features/vault/presentation/vault_session_state.dart';
import 'package:lockspire_bridge/lockspire_bridge.dart';

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

    testWidgets('avisa si el navegador tiene registrada otra copia de '
        'Lockspire, y conectar la reemplaza (2026-09-30)', (tester) async {
      final (app, robot) = await _desktopUnlocked(tester);
      app.nativeMessaging
        ..otherCopyIn = {SupportedBrowser.chrome}
        ..otherCopySystemWideIn = {SupportedBrowser.chrome};
      await _openBrowser(robot);

      expect(
        find.textContaining('En Google Chrome está registrada otra copia'),
        findsOneWidget,
      );
      expect(
        find.textContaining('El registro para todo el equipo apunta a otra'),
        findsOneWidget,
      );
      // Con un registro ajeno para todo el equipo, se puede quitar.
      await robot.reveal(find.text('Quitar registro'));
      expect(find.text('Quitar registro'), findsOneWidget);

      await robot.tapText('Conectar con Chrome/Edge');
      await robot.tapText('Quitar registro');

      expect(find.textContaining('otra copia'), findsNothing);
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

  group('Guardar contraseñas desde el navegador (ADR 0034)', () {
    Future<Map<String, Object?>> fromExtension(
      TestApp app,
      WidgetTester tester,
      BridgeRequest request,
    ) async {
      // La respuesta llega mientras corre el reloj de la prueba (guardar la
      // bóveda es asíncrono).
      Map<String, Object?>? response;
      unawaited(
        app.container
            .read(bridgeRequestHandlerProvider)(request)
            .then((r) => response = r),
      );
      final robot = AppRobot(tester);
      for (var i = 0; i < 50 && response == null; i++) {
        await robot.settle();
      }
      return response!;
    }

    SaveLoginRequest save(String password) => SaveLoginRequest(
      'a',
      origin: 'https://www.banco.ejemplo',
      username: 'ana',
      password: password,
    );

    VaultEntry entryNamed(TestApp app, String title) =>
        (app.container.read(vaultSessionControllerProvider).value!
                as VaultSessionUnlocked)
            .vault
            .entries
            .firstWhere((e) => e.title == title);

    testWidgets('un inicio de sesión nuevo queda como entrada del sitio', (
      tester,
    ) async {
      final (app, _) = await _desktopUnlocked(tester);

      final check = await fromExtension(
        app,
        tester,
        const CheckLoginRequest(
          'c',
          origin: 'https://www.banco.ejemplo',
          username: 'ana',
          password: 'Secreta-1',
        ),
      );
      expect(check['status'], 'new');
      expect(
        await fromExtension(app, tester, save('Secreta-1')),
        okResponse('a'),
      );

      expect(find.text('banco.ejemplo'), findsOneWidget);
      final entry = entryNamed(app, 'banco.ejemplo');
      expect(entry.fields, {
        'username': 'ana',
        'password': 'Secreta-1',
        'url': 'https://banco.ejemplo',
      });
    });

    testWidgets('actualizar cambia la contraseña y guarda la anterior en el '
        'historial', (tester) async {
      final (app, robot) = await _desktopUnlocked(tester);
      await robot.addPassword(
        title: 'Banco',
        username: 'ana',
        password: 'Vieja-1',
        url: 'https://banco.ejemplo',
      );

      await fromExtension(app, tester, save('Nueva-2'));

      final entry = entryNamed(app, 'Banco');
      expect(entry.fields['password'], 'Nueva-2');
      expect(entry.fieldHistory['password']!.single.value, 'Vieja-1');
    });

    testWidgets('con la bóveda bloqueada, se guarda al desbloquear y lo '
        'avisa', (tester) async {
      final (app, robot) = await _desktopUnlocked(tester);
      await robot.lock();
      app.window.visible = false;

      expect(
        await fromExtension(app, tester, save('Secreta-1')),
        unlockRequiredResponse('a'),
      );
      expect(app.window.visible, isTrue, reason: 'la app sale al frente');

      await robot.unlock(_master);

      expect(
        find.text('Se guardó la contraseña de banco.ejemplo.'),
        findsOneWidget,
      );
      expect(entryNamed(app, 'banco.ejemplo').fields['password'], 'Secreta-1');
    });

    testWidgets('si no se desbloquea en 10 minutos, se descarta: la '
        'contraseña no queda en memoria (S18)', (tester) async {
      final (app, robot) = await _desktopUnlocked(tester);
      await robot.lock();
      await fromExtension(app, tester, save('Secreta-1'));

      await tester.pump(pendingBrowserLoginTtl + const Duration(seconds: 1));
      expect(app.container.read(pendingBrowserLoginsProvider), isEmpty);
      await robot.unlock(_master);

      expect(find.textContaining('Se guardó la contraseña'), findsNothing);
      expect(find.text('banco.ejemplo'), findsNothing);
    });

    testWidgets('"Nunca en este sitio" aparece en Navegador y se puede '
        'quitar', (tester) async {
      final (app, robot) = await _desktopUnlocked(tester);
      await fromExtension(
        app,
        tester,
        const NeverSaveForOriginRequest(
          'n',
          origin: 'https://www.banco.ejemplo',
        ),
      );

      await _openBrowser(robot);
      await robot.reveal(find.text('banco.ejemplo'));
      expect(
        find.text('Sitios donde no se ofrece guardar contraseñas'),
        findsOneWidget,
      );

      final remove = find.byTooltip('Volver a ofrecer en banco.ejemplo');
      await tester.ensureVisible(remove);
      await robot.tapTooltip('Volver a ofrecer en banco.ejemplo');

      expect(find.text('banco.ejemplo'), findsNothing);
      final check = await fromExtension(
        app,
        tester,
        const CheckLoginRequest(
          'c',
          origin: 'https://banco.ejemplo',
          username: 'ana',
          password: 'x',
        ),
      );
      expect(check['status'], 'new');
    });
  });
}
