// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Gabriel Ángel Montoya Rico

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lockspire/l10n/l10n.dart';

import '../../../vault/presentation/vault_session_controller.dart';
import '../../../vault/presentation/vault_session_state.dart';
import '../../domain/browser_login.dart';
import '../providers/browser_login_providers.dart';

/// Guarda al desbloquear los inicios de sesión que el usuario aceptó en el
/// navegador con la bóveda bloqueada (ADR 0034), y avisa de cada uno.
class BrowserLoginSaveListener extends ConsumerWidget {
  final Widget child;

  const BrowserLoginSaveListener({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    void saveIfUnlocked() {
      final session = ref.read(vaultSessionControllerProvider).value;
      if (session is! VaultSessionUnlocked) return;
      final logins = ref.read(pendingBrowserLoginsProvider.notifier).take();
      if (logins.isNotEmpty) _save(context, ref, logins);
    }

    ref.listen(vaultSessionControllerProvider, (_, _) => saveIfUnlocked());
    ref.listen(pendingBrowserLoginsProvider, (_, _) => saveIfUnlocked());
    return child;
  }

  Future<void> _save(
    BuildContext context,
    WidgetRef ref,
    List<BrowserLogin> logins,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final l10n = context.l10n;
    final save = ref.read(browserLoginSaverProvider);
    for (final login in logins) {
      // Se compara con la bóveda de ahora: pudo sincronizarse o editarse
      // mientras estaba bloqueada.
      final session = ref.read(vaultSessionControllerProvider).value;
      if (session is! VaultSessionUnlocked) return;
      try {
        await save(login, matchLogin(session.vault, login));
        messenger.showSnackBar(
          SnackBar(content: Text(l10n.browserLoginSaved(login.site))),
        );
      } catch (_) {
        messenger.showSnackBar(
          SnackBar(content: Text(l10n.browserLoginSaveFailed(login.site))),
        );
      }
    }
  }
}
