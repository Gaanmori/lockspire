// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Lockspire

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../design/lockspire_spacing.dart';
import '../vault_session_controller.dart';
import '../vault_session_state.dart';
import 'create_vault_screen.dart';
import 'unlock_vault_screen.dart';
import 'vault_unlocked_screen.dart';

/// Punto de entrada de la feature `vault`: decide qué pantalla mostrar
/// según el estado inicial de la sesión (¿existe una bóveda? ¿está
/// desbloqueada?). Sin `Navigator` — es un solo swap condicional.
class VaultGateScreen extends ConsumerWidget {
  const VaultGateScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncState = ref.watch(vaultSessionControllerProvider);

    return asyncState.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (error, stackTrace) => Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Ocurrió un error: $error', textAlign: TextAlign.center),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () =>
                      ref.invalidate(vaultSessionControllerProvider),
                  child: const Text('Reintentar'),
                ),
              ],
            ),
          ),
        ),
      ),
      data: (state) => switch (state) {
        VaultSessionNoVault() => const CreateVaultScreen(),
        VaultSessionLocked() => const UnlockVaultScreen(),
        VaultSessionUnlocked(:final vault) => VaultUnlockedScreen(vault: vault),
      },
    );
  }
}
