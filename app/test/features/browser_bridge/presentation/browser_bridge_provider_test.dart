// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Gabriel Ángel Montoya Rico

import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lockspire/features/browser_bridge/presentation/providers/browser_bridge_provider.dart';
import 'package:lockspire/features/desktop/presentation/providers/is_desktop_shell_provider.dart';
import 'package:lockspire_bridge/lockspire_bridge.dart';

class _Server implements BridgeServer {
  var closed = false;
  @override
  Future<void> close() async => closed = true;
}

/// El canal de la extensión cuando otra instancia de Lockspire lo tiene
/// (ADR 0012, 0013).
void main() {
  test('si otra instancia tiene el canal, reintenta y lo toma cuando esa '
      'se cierra, sin reiniciar la app', () {
    fakeAsync((clock) {
      var otherInstanceOpen = true;
      var attempts = 0;
      final server = _Server();
      final container = ProviderContainer(
        overrides: [
          isDesktopShellProvider.overrideWith((ref) => true),
          bridgeRetryDelayProvider.overrideWithValue(
            const Duration(seconds: 5),
          ),
          bridgeServerStarterProvider.overrideWithValue((handler) async {
            attempts++;
            if (otherInstanceOpen) throw BridgeServerAlreadyRunningException();
            return server;
          }),
        ],
      );
      addTearDown(container.dispose);
      final subscription = container.listen(browserBridgeProvider, (_, _) {});
      addTearDown(subscription.close);

      clock.flushMicrotasks();
      expect(
        container.read(browserBridgeProvider).value,
        BrowserBridgeStatus.anotherInstance,
      );

      clock.elapse(const Duration(seconds: 5));
      expect(attempts, 2, reason: 'sigue reintentando');

      otherInstanceOpen = false;
      clock.elapse(const Duration(seconds: 5));
      expect(
        container.read(browserBridgeProvider).value,
        BrowserBridgeStatus.running,
      );

      // Con el canal tomado, ya no reintenta.
      clock.elapse(const Duration(seconds: 30));
      expect(attempts, 3);
    });
  });

  test('en Android no hay canal con la extensión', () async {
    final container = ProviderContainer(
      overrides: [isDesktopShellProvider.overrideWith((ref) => false)],
    );
    addTearDown(container.dispose);

    expect(
      await container.read(browserBridgeProvider.future),
      BrowserBridgeStatus.unsupported,
    );
  });
}
