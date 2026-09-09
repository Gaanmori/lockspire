// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Lockspire

import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lockspire/features/vault/presentation/providers/vault_file_path_provider.dart';
import 'package:lockspire/main.dart';

void main() {
  testWidgets(
    'Sin bóveda existente, la app arranca en la pantalla de creación',
    (WidgetTester tester) async {
      final vaultPath =
          '${Directory.systemTemp.path}${Platform.pathSeparator}'
          'lockspire_widget_test_${DateTime.now().microsecondsSinceEpoch}.vault';

      await tester.pumpWidget(
        ProviderScope(
          // Evita depender del canal de plataforma real de path_provider,
          // que no está disponible en el entorno de `flutter test`.
          overrides: [
            vaultFilePathProvider.overrideWith((ref) async => vaultPath),
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
      // runAsync para dejarla completar de verdad antes de re-pintar.
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 300)),
      );
      await tester.pump();

      expect(find.text('Crear bóveda'), findsWidgets);
    },
  );
}
