// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Gabriel Ángel Montoya Rico

import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lockspire/features/desktop/presentation/providers/is_desktop_shell_provider.dart';
import 'package:lockspire/features/vault/presentation/providers/vault_file_path_provider.dart';
import 'package:lockspire/main.dart';

import 'support/app_robot.dart';

void main() {
  testWidgets(
    'Sin bóveda existente, la app arranca en la pantalla de creación',
    (WidgetTester tester) async {
      final vaultPath =
          '${Directory.systemTemp.path}${Platform.pathSeparator}'
          'lockspire_widget_test_${DateTime.now().microsecondsSinceEpoch}.vault';

      // Sistema en español: la app lo sigue (ADR 0032).
      tester.platformDispatcher.localesTestValue = const [Locale('es', 'CO')];
      addTearDown(tester.platformDispatcher.clearLocalesTestValue);

      await tester.pumpWidget(
        ProviderScope(
          // Evita depender del canal de plataforma real de path_provider,
          // que no está disponible en el entorno de `flutter test`.
          overrides: [
            vaultFilePathProvider.overrideWith((ref) async => vaultPath),
            // Sin ventana ni bandeja reales en `flutter test` (ADR 0012).
            isDesktopShellProvider.overrideWith((ref) => false),
          ],
          child: const MyApp(),
        ),
      );

      // No se usa pumpAndSettle: mientras el estado inicial está "loading"
      // se muestra un CircularProgressIndicator indeterminado, cuya
      // animación nunca "asienta" — pumpAndSettle esperaría hasta agotar
      // su timeout. Además, pump(duration) solo adelanta el reloj
      // simulado de las animaciones, no el tiempo real: la cadena de
      // providers hace I/O real (dart:io), así que hace falta
      // dejarla completar de verdad: waitForIo reintenta hasta que aparece.
      await AppRobot(tester).waitForIo(find.text('Crear bóveda'));

      expect(find.text('Crear bóveda'), findsWidgets);
    },
  );
}
