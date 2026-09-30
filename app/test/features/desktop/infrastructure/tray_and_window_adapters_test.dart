// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Gabriel Ángel Montoya Rico

import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:lockspire/features/desktop/domain/ports/tray_port.dart';
import 'package:lockspire/features/desktop/infrastructure/tray_manager_adapter.dart';
import 'package:lockspire/features/desktop/infrastructure/window_manager_adapter.dart';
import 'package:lockspire/features/desktop/presentation/providers/desktop_ports_providers.dart';

import '../../../support/fake_method_channel.dart';

const _menu = TrayMenu(
  open: 'Abrir',
  lock: 'Bloquear',
  quit: 'Salir',
  lockEnabled: false,
);

/// La bandeja y la ventana de escritorio (ADR 0012) sobre los canales de
/// `tray_manager` y `window_manager`, con el lado nativo simulado.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Bandeja', () {
    late FakeMethodChannel native;
    late TrayManagerAdapter tray;
    late List<TrayAction> actions;

    setUp(() {
      native = FakeMethodChannel('tray_manager');
      tray = TrayManagerAdapter();
      // Antes de desmontar el canal simulado (addTearDown va en orden
      // inverso).
      addTearDown(() => tray.destroy());
      actions = [];
      final subscription = tray.actions.listen(actions.add);
      addTearDown(subscription.cancel);
    });

    test('el ícono de la app instalada: .ico con tooltip en Windows, .png '
        'sin tooltip en Linux', () async {
      await tray.showDefaultIcon();

      final iconPath = (native.argumentsOf('setIcon') as Map)['iconPath'];
      if (Platform.isWindows) {
        expect(iconPath, endsWith('tray_icon.ico'));
        expect(native.argumentsOf('setToolTip'), {'toolTip': 'Lockspire'});
      } else {
        expect(iconPath, endsWith('tray_icon.png'));
        expect(native.methods, isNot(contains('setToolTip')));
      }
    });

    test('clic izquierdo abre; clic derecho muestra el menú', () async {
      await native.emit('onTrayIconMouseDown');
      await native.emit('onTrayIconRightMouseDown');
      await pumpEventQueue();

      expect(actions, [TrayAction.open]);
      expect(native.methods, contains('popUpContextMenu'));
    });

    test('el menú lleva los textos del idioma, "Bloquear" desactivado sin '
        'bóveda abierta, y cada opción llega como acción', () async {
      await tray.setMenu(_menu);
      final items =
          ((native.argumentsOf('setContextMenu') as Map)['menu']
                  as Map)['items']
              as List;
      final byLabel = {
        for (final item in items.cast<Map>())
          if (item['type'] != 'separator') item['label']: item,
      };
      expect(byLabel.keys, ['Abrir', 'Bloquear', 'Salir']);
      expect(byLabel['Bloquear']!['disabled'], isTrue);

      for (final label in ['Salir', 'Abrir']) {
        await native.emit('onTrayMenuItemClick', {'id': byLabel[label]!['id']});
      }
      await pumpEventQueue();

      expect(actions, [TrayAction.quit, TrayAction.open]);
    });

    test('al cambiar de perfil, el adaptador viejo deja de escuchar y el '
        'ícono se queda (ADR 0039)', () async {
      final next = TrayManagerAdapter();
      addTearDown(next.dispose);

      await tray.dispose();
      await native.emit('onTrayIconRightMouseDown');
      await pumpEventQueue();

      expect(native.methods, isNot(contains('destroy')));
      // Un solo menú: el del adaptador nuevo.
      expect(
        native.methods.where((m) => m == 'popUpContextMenu'),
        hasLength(1),
      );
      await native.emit('onTrayIconMouseDown');
      expect(actions, isEmpty);
    });

    test('al cerrar la app el ícono desaparece', () async {
      await tray.destroy();

      expect(native.methods, contains('destroy'));
      // Después de destruida ya no escucha la bandeja.
      await native.emit('onTrayIconMouseDown');
      expect(actions, isEmpty);
    });
  });

  group('Ventana', () {
    late FakeMethodChannel native;
    late WindowManagerAdapter window;

    setUp(() {
      native = FakeMethodChannel('window_manager')..answer('isMinimized', true);
      window = WindowManagerAdapter();
    });

    test('la X avisa en vez de cerrar (la app sigue en la bandeja)', () async {
      var requests = 0;
      final subscription = window.closeRequests.listen((_) => requests++);
      addTearDown(subscription.cancel);

      await window.interceptClose(true);
      await native.emit('onEvent', {'eventName': 'close'});
      await pumpEventQueue();

      expect(native.argumentsOf('setPreventClose'), {'isPreventClose': true});
      expect(requests, 1);
      await window.destroy();
    });

    test('al cambiar de perfil, el adaptador viejo deja de escuchar sin '
        'cerrar la ventana (ADR 0039)', () async {
      var requests = 0;
      final subscription = window.closeRequests.listen((_) => requests++);
      addTearDown(subscription.cancel);

      await window.dispose();
      await native.emit('onEvent', {'eventName': 'close'});
      await pumpEventQueue();

      expect(requests, 0);
      expect(native.methods, isNot(contains('destroy')));
    });

    test('mostrar restaura la ventana minimizada y le da el foco', () async {
      await window.show();

      expect(
        native.methods,
        containsAllInOrder(['isMinimized', 'restore', 'show', 'focus']),
      );
      await window.destroy();
    });

    test('ocultar, cambiar el ícono y destruir llegan a la '
        'ventana', () async {
      await window.hide();
      // Absoluta en el sistema donde corre el test: window_manager antepone
      // la carpeta de assets a una ruta relativa, y `C:\...` no es
      // absoluta en Linux (así falló en la CI, 2026-09-30).
      final icon = p.join(Directory.systemTemp.path, 'lockspire.ico');
      await window.setIcon(icon);
      await window.destroy();

      expect(
        native.methods,
        containsAllInOrder(['hide', 'setIcon', 'destroy']),
      );
      expect((native.argumentsOf('setIcon') as Map)['iconPath'], icon);
    });
  });

  // Regresión (revisión 2026-09-30 de ADR 0039): cada perfil crea sus
  // adaptadores; si el contenedor viejo no los soltaba, seguían escuchando.
  test('descartar el contenedor de un perfil suelta la bandeja y la '
      'ventana', () async {
    final tray = FakeMethodChannel('tray_manager');
    final window = FakeMethodChannel('window_manager');
    final container = ProviderContainer();
    final closes = <void>[];
    container.read(desktopWindowPortProvider).closeRequests.listen(closes.add);
    container.read(trayPortProvider);

    container.dispose();
    await pumpEventQueue();
    await tray.emit('onTrayIconRightMouseDown');
    await window.emit('onEvent', {'eventName': 'close'});
    await pumpEventQueue();

    expect(tray.methods, isNot(contains('popUpContextMenu')));
    expect(closes, isEmpty);
  });
}
