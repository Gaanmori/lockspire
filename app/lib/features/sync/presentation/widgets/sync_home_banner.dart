// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Gabriel Ángel Montoya Rico

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/sync_vault_use_case.dart';
import '../screens/sync_settings_screen.dart';
import '../sync_controller.dart';
import 'package:lockspire/l10n/l10n.dart';
import 'package:lockspire/l10n/localized_error.dart';

/// Aviso visible en toda la app cuando este dispositivo sincroniza con una
/// nube distinta de la de la bóveda, o la bóveda se acaba de mudar (ADR
/// 0023). Sin ese caso no ocupa espacio.
class SyncHomeBanner extends ConsumerWidget {
  const SyncHomeBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sync = ref.watch(syncControllerProvider);
    final error = sync.error;
    final String? message = switch ((error, sync.value)) {
      (SyncHomeMismatchException e, _) => localizeError(context.l10n, e),
      (_, SyncVaultMoved(:final to)) => context.l10n.syncHomeMovedBanner(
        syncProviderName(to),
      ),
      _ => null,
    };
    if (message == null) return const SizedBox.shrink();

    return MaterialBanner(
      forceActionsBelow: true,
      leading: const Icon(Icons.cloud_sync_outlined),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (_) => const SyncSettingsScreen()),
          ),
          child: Text(context.l10n.syncHomeGoToSync),
        ),
      ],
    );
  }
}
