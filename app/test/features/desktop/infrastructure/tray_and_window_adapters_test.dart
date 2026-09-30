// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Gabriel Ángel Montoya Rico

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lockspire/features/desktop/domain/ports/tray_port.dart';
import 'package:lockspire/features/desktop/infrastructure/tray_manager_adapter.dart';
import 'package:lockspire/features/desktop/infrastructure/window_manager_adapter.dart';

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
      await window.setIcon(r'C:\iconos\lockspire.ico');
      await window.destroy();

      expect(
        native.methods,
        containsAllInOrder(['hide', 'setIcon', 'destroy']),
      );
      expect(
        (native.argumentsOf('setIcon') as Map)['iconPath'],
        r'C:\iconos\lockspire.ico',
      );
    });
  });
}
