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
import 'package:lockspire/l10n/l10n.dart';
import 'package:lockspire/l10n/localized_error.dart';

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

  /// Encima de las pantallas de crear y desbloquear, p. ej. la lista de
  /// perfiles (ADR 0039).
  final Widget? lockedHeader;

  const VaultGateScreen({
    super.key,
    required this.unlockedBuilder,
    this.restoreVaultBuilder,
    this.lockedHeader,
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
                Text(
                  context.l10n.commonErrorDetail(
                    localizeError(context.l10n, error),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: LockspireSpacing.md),
                FilledButton(
                  onPressed: () =>
                      ref.invalidate(vaultSessionControllerProvider),
                  child: Text(context.l10n.commonRetry),
                ),
              ],
            ),
          ),
        ),
      ),
      data: (state) => switch (state) {
        VaultSessionNoVault() => CreateVaultScreen(
          restoreVaultBuilder: restoreVaultBuilder,
          header: lockedHeader,
        ),
        VaultSessionLocked() => UnlockVaultScreen(header: lockedHeader),
        VaultSessionUnlocked(:final vault) => unlockedBuilder(vault),
      },
    );
  }
}
