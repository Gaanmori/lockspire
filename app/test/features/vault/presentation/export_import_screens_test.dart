// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Gabriel Ángel Montoya Rico

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lockspire/features/clipboard/domain/ports/secure_clipboard_port.dart';
import 'package:lockspire/features/clipboard/presentation/providers/clipboard_guard_provider.dart';
import 'package:lockspire/features/vault/presentation/providers/biometric_auth_port_provider.dart';
import 'package:lockspire/features/vault/presentation/providers/crypto_port_provider.dart';
import 'package:lockspire/features/vault/presentation/providers/master_password_reminder_settings_port_provider.dart';
import 'package:lockspire/features/vault/presentation/providers/password_unlock_history_port_provider.dart';
import 'package:lockspire/features/vault/presentation/providers/vault_storage_port_provider.dart';
import 'package:lockspire/features/vault/presentation/screens/export_screen.dart';
import 'package:lockspire/features/vault/presentation/screens/import_screen.dart';
import 'package:lockspire/features/vault/presentation/vault_session_controller.dart';

import '../application/fakes.dart';
import 'package:lockspire/l10n/l10n.dart';

const _password = 'contraseña de prueba larga';

class _NoClipboard implements SecureClipboardPort {
  @override
  Future<void> copySensitive(
    String text, {
    required Duration clearAfter,
  }) async {}

  @override
  Future<void> clearIfStillOurs() async {}
}

/// Una bóveda desbloqueada con dependencias falsas, como en los tests de
/// la sesión.
Future<ProviderContainer> _unlockedContainer() async {
  final container = ProviderContainer(
    overrides: [
      cryptoPortProvider.overrideWith((ref) async => FakeCryptoPort()),
      vaultStoragePortProvider.overrideWith(
        (ref) async => FakeVaultStoragePort(),
      ),
      biometricAuthPortProvider.overrideWith((ref) => FakeBiometricAuthPort()),
      secureClipboardPortProvider.overrideWithValue(_NoClipboard()),
      passwordUnlockHistoryPortProvider.overrideWithValue(
        FakePasswordUnlockHistoryPort(),
      ),
      masterPasswordReminderSettingsPortProvider.overrideWithValue(
        FakeMasterPasswordReminderSettingsPort(),
      ),
    ],
  );
  await container.read(vaultSessionControllerProvider.future);
  await container
      .read(vaultSessionControllerProvider.notifier)
      .createVault(_password);
  return container;
}

Future<void> _pump(
  WidgetTester tester,
  ProviderContainer container,
  Widget screen,
) async {
  addTearDown(container.dispose);
  // Alta como un teléfono: la lista de Exportar solo construye lo que se
  // ve, y en los 800×600 por defecto el último formato y el campo de
  // contraseña quedaban fuera.
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        locale: const Locale('es'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: screen,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('Exportar (ADR 0027)', () {
    testWidgets('ofrece el respaldo cifrado y los tres formatos abiertos', (
      tester,
    ) async {
      final container = await tester.runAsync(_unlockedContainer);
      await _pump(tester, container!, const ExportScreen());

      expect(find.text('Respaldo de Lockspire (cifrado)'), findsOneWidget);
      expect(find.text('CSV de Bitwarden'), findsOneWidget);
      expect(find.text('JSON de Bitwarden'), findsOneWidget);
      expect(find.text('CSV de Chrome'), findsOneWidget);
    });

    testWidgets('una contraseña maestra incorrecta no exporta nada', (
      tester,
    ) async {
      final container = await tester.runAsync(_unlockedContainer);
      await _pump(tester, container!, const ExportScreen());

      await tester.enterText(find.byType(TextField), 'no es esta');
      await tester.runAsync(() async {
        await tester.tap(find.widgetWithText(FilledButton, 'Exportar'));
        await Future<void>.delayed(const Duration(milliseconds: 100));
      });
      await tester.pumpAndSettle();

      expect(find.text('La contraseña maestra no es correcta'), findsOneWidget);
    });

    testWidgets('un formato sin cifrar se advierte en pantalla y se confirma '
        'antes de exportar', (tester) async {
      final container = await tester.runAsync(_unlockedContainer);
      await _pump(tester, container!, const ExportScreen());

      await tester.tap(find.text('CSV de Chrome'));
      await tester.pumpAndSettle();
      expect(find.textContaining('no está cifrado'), findsOneWidget);

      await tester.enterText(find.byType(TextField), _password);
      await tester.tap(find.widgetWithText(FilledButton, 'Exportar'));
      await tester.pumpAndSettle();
      expect(find.text('El archivo no va a estar cifrado'), findsOneWidget);

      // Cancelar no verifica ni guarda nada.
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();
      expect(find.text('El archivo no va a estar cifrado'), findsNothing);
      expect(find.text('Exportación lista'), findsNothing);
    });
  });

  group('Importar (ADR 0027)', () {
    testWidgets('explica de dónde se puede importar', (tester) async {
      final container = await tester.runAsync(_unlockedContainer);
      await _pump(tester, container!, const ImportScreen());

      expect(find.text('SafeInCloud — XML'), findsOneWidget);
      expect(find.text('Bitwarden — CSV o JSON sin cifrar'), findsOneWidget);
      expect(
        find.text('Respaldo de Lockspire — .lockspire, con su contraseña'),
        findsOneWidget,
      );
      expect(find.text('Elegir archivo'), findsOneWidget);
    });
  });
}
