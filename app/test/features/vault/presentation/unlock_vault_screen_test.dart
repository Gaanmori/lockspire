// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Gabriel Ángel Montoya Rico

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lockspire/features/vault/presentation/providers/biometric_auth_port_provider.dart';
import 'package:lockspire/features/vault/presentation/providers/clock_provider.dart';
import 'package:lockspire/features/vault/presentation/providers/crypto_port_provider.dart';
import 'package:lockspire/features/vault/presentation/providers/master_password_reminder_settings_port_provider.dart';
import 'package:lockspire/features/vault/presentation/providers/password_unlock_history_port_provider.dart';
import 'package:lockspire/features/vault/presentation/providers/vault_storage_port_provider.dart';
import 'package:lockspire/features/vault/presentation/screens/unlock_vault_screen.dart';

import '../../../support/fakes/vault_fakes.dart';
import 'package:lockspire/l10n/l10n.dart';

/// Pantalla de desbloqueo con biometría activa y un último desbloqueo con
/// contraseña en [lastPasswordUnlock].
Future<void> _pump(WidgetTester tester, DateTime? lastPasswordUnlock) async {
  final now = DateTime.utc(2026, 9, 25, 12);
  final biometric = FakeBiometricAuthPort();
  await biometric.storeKey(key: Uint8List.fromList([1, 2, 3]));

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        biometricAuthPortProvider.overrideWithValue(biometric),
        passwordUnlockHistoryPortProvider.overrideWithValue(
          FakePasswordUnlockHistoryPort(lastPasswordUnlock),
        ),
        masterPasswordReminderSettingsPortProvider.overrideWithValue(
          FakeMasterPasswordReminderSettingsPort(),
        ),
        clockProvider.overrideWithValue(() => now),
        cryptoPortProvider.overrideWith((ref) async => FakeCryptoPort()),
        vaultStoragePortProvider.overrideWith(
          (ref) async => FakeVaultStoragePort(),
        ),
      ],
      child: const MaterialApp(
        locale: Locale('es'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: UnlockVaultScreen(),
      ),
    ),
  );
  // Deja resolver las lecturas asíncronas de los puertos y el intento
  // biométrico automático (que el fake cancela: readKey → null).
  for (var i = 0; i < 5; i++) {
    await tester.pump();
  }
}

void main() {
  // Regresión del bug real de ADR 0017: la comprobación era un provider
  // auto-dispose leído con ref.read(...future) desde la pantalla; se
  // descartaba a mitad de la lectura y nunca se ofrecía la biometría.
  testWidgets('dentro del plazo, ofrece la biometría', (tester) async {
    await _pump(tester, DateTime.utc(2026, 9, 25, 11));
    expect(find.textContaining('Usar '), findsOneWidget);
    expect(find.textContaining('Por seguridad'), findsNothing);
  });

  testWidgets('vencido el plazo, pide la contraseña y explica por qué', (
    tester,
  ) async {
    await _pump(tester, DateTime.utc(2026, 9, 1));
    expect(find.textContaining('Usar '), findsNothing);
    expect(find.textContaining('Por seguridad'), findsOneWidget);
  });
}
