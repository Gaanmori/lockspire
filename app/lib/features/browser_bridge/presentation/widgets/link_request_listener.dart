// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Lockspire

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../vault/presentation/vault_session_controller.dart';
import '../../../vault/presentation/vault_entries_controller.dart';
import '../../../vault/presentation/vault_session_state.dart';
import '../../application/handle_bridge_request.dart';
import '../providers/pending_link_request_provider.dart';

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
        title: const Text('¿Vincular este sitio?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('La extensión pide usar "${request.entryTitle}" en:'),
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
                  ? 'La entrada no tenía ninguna URL.'
                  : 'Reemplaza la URL actual: ${request.currentUrl}',
            ),
            const SizedBox(height: 12),
            const Text(
              'Comprobá que la dirección sea la real: si es un sitio '
              'falso que imita al original, le estarías dando esta '
              'contraseña.',
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Vincular'),
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
    if (entry == null) {
      messenger.showSnackBar(
        const SnackBar(content: Text('La entrada ya no existe.')),
      );
      return;
    }
    try {
      await ref
          .read(vaultEntriesControllerProvider)
          .updateEntry(
            id: entry.id,
            title: entry.title,
            fields: {...entry.fields, 'url': request.newUrl},
          );
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            '"${entry.title}" vinculada a $newHost. Volvé a abrir la '
            'extensión para rellenar.',
          ),
        ),
      );
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(content: Text('No se pudo guardar el vínculo.')),
      );
    }
  }
}
