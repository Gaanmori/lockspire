// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Gabriel Ángel Montoya Rico

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../design/lockspire_spacing.dart';
import '../../domain/entities/vault.dart';
import '../vault_session_controller.dart';
import '../vault_session_state.dart';
import 'create_vault_screen.dart';
import 'unlock_vault_screen.dart';

/// Punto de entrada de la feature `vault`: decide qué pantalla mostrar
/// según el estado inicial de la sesión (¿existe una bóveda? ¿está
/// desbloqueada?). Sin `Navigator` — es un solo swap condicional.
///
/// Qué se muestra con la bóveda desbloqueada lo decide quien la usa
/// ([unlockedBuilder]): así `vault` no depende de la navegación de la app
/// (`home`), que a su vez sí depende de `vault` — sin ciclo entre features.
class VaultGateScreen extends ConsumerWidget {
  final Widget Function(Vault vault) unlockedBuilder;

  /// Ver `CreateVaultScreen.restoreVaultBuilder`.
  final WidgetBuilder? restoreVaultBuilder;

  const VaultGateScreen({
    super.key,
    required this.unlockedBuilder,
    this.restoreVaultBuilder,
  });

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
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Ocurrió un error: $error', textAlign: TextAlign.center),
                const SizedBox(height: LockspireSpacing.md),
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
        VaultSessionNoVault() => CreateVaultScreen(
          restoreVaultBuilder: restoreVaultBuilder,
        ),
        VaultSessionLocked() => const UnlockVaultScreen(),
        VaultSessionUnlocked(:final vault) => unlockedBuilder(vault),
      },
    );
  }
}
