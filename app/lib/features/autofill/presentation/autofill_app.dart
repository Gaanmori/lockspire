// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Lockspire

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../design/lockspire_spacing.dart';
import '../../appearance/domain/appearance_preference.dart';
import '../../appearance/presentation/appearance_controller.dart';
import '../../vault/presentation/screens/unlock_vault_screen.dart';
import '../../vault/presentation/vault_session_controller.dart';
import '../../vault/presentation/vault_session_state.dart';
import 'screens/autofill_screen.dart';

/// Raíz de la app cuando `AutofillActivity` (ADR 0011) la lanza — activada
/// por `main.dart` cuando la ruta inicial es `/autofill` (ver
/// `AutofillActivity.getInitialRoute()`). Reusa el flujo de desbloqueo
/// normal (contraseña o biometría) sin ningún camino nuevo; solo cambia
/// qué pantalla se muestra una vez desbloqueada.
class AutofillApp extends ConsumerWidget {
  const AutofillApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appearance =
        ref.watch(appearanceControllerProvider).value ??
        AppearancePreference.defaults;
    return MaterialApp(
      title: 'Lockspire',
      theme: appearance.lightTheme,
      darkTheme: appearance.darkTheme,
      themeMode: appearance.themeMode,
      home: const _AutofillGate(),
    );
  }
}

class _AutofillGate extends ConsumerWidget {
  const _AutofillGate();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncState = ref.watch(vaultSessionControllerProvider);

    return asyncState.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (error, stackTrace) => Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(LockspireSpacing.lg),
            child: Text(
              'Ocurrió un error: $error',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
      data: (state) => switch (state) {
        VaultSessionUnlocked(:final vault) => AutofillScreen(vault: vault),
        VaultSessionLocked() => const UnlockVaultScreen(),
        // No debería pasar en la práctica (autofill solo tiene sentido con
        // una bóveda ya creada) — se cubre igual para no crashear.
        VaultSessionNoVault() => const _NoVaultView(),
      },
    );
  }
}

class _NoVaultView extends StatelessWidget {
  const _NoVaultView();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(LockspireSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Todavía no creaste una bóveda en Lockspire.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: LockspireSpacing.lg),
              FilledButton(
                onPressed: () => const MethodChannel(
                  'com.lockspire.lockspire/autofill',
                ).invokeMethod('cancel'),
                child: const Text('Cerrar'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
