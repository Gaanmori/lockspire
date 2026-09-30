// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Gabriel Ángel Montoya Rico

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../vault/presentation/vault_session_controller.dart';
import '../../../vault/presentation/vault_entries_controller.dart';
import '../../../vault/presentation/vault_session_state.dart';
import '../../application/handle_bridge_request.dart';
import '../providers/pending_link_request_provider.dart';
import 'package:lockspire/l10n/l10n.dart';
import '../../../vault/domain/entities/entry_fields.dart';

/// Muestra en la ventana de Lockspire la confirmación de vincular un sitio
/// a una entrada que pidió la extensión (ADR 0015). Es la interfaz de
/// confianza: la extensión solo propone, la bóveda solo cambia aquí.
class LinkRequestListener extends ConsumerWidget {
  final Widget child;

  const LinkRequestListener({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen<LinkRequest?>(pendingLinkRequestProvider, (previous, next) {
      if (next == null) return;
      ref.read(pendingLinkRequestProvider.notifier).clear();
      _confirm(context, ref, next);
    });
    return child;
  }

  Future<void> _confirm(
    BuildContext context,
    WidgetRef ref,
    LinkRequest request,
  ) async {
    final newHost = Uri.parse(request.newUrl).host;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.l10n.linkTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(context.l10n.linkBody(request.entryTitle)),
            const SizedBox(height: 8),
            SelectableText(
              newHost,
              style: Theme.of(
                dialogContext,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            Text(
              request.currentUrl.isEmpty
                  ? context.l10n.linkNoUrl
                  : context.l10n.linkReplacesUrl(request.currentUrl),
            ),
            const SizedBox(height: 12),
            Text(context.l10n.linkPhishingWarning),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(context.l10n.commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(context.l10n.linkConfirm),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    // Se relee la entrada: la bóveda pudo bloquearse, sincronizarse o
    // editarse mientras el diálogo estaba abierto.
    final session = ref.read(vaultSessionControllerProvider).value;
    if (session is! VaultSessionUnlocked) return;
    final entry = session.vault.entries
        .where((e) => e.id == request.entryId && !e.deleted)
        .firstOrNull;
    final messenger = ScaffoldMessenger.of(context);
    final l10n = context.l10n;
    if (entry == null) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.linkEntryGone)));
      return;
    }
    try {
      await ref
          .read(vaultEntriesControllerProvider)
          .updateEntry(
            id: entry.id,
            title: entry.title,
            fields: {...entry.fields, EntryFields.url: request.newUrl},
          );
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.linkDone(entry.title, newHost))),
      );
    } catch (_) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.linkSaveFailed)));
    }
  }
}
