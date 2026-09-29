// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Gabriel Ángel Montoya Rico

import 'dart:typed_data';

import 'package:flutter/material.dart';
import '../../../../design/lockspire_colors.dart';
import '../../../../design/lockspire_spacing.dart';
import '../../domain/entities/entry_fields.dart';
import '../../domain/entities/vault_entry.dart';
import 'entry_avatar.dart';
import 'package:lockspire/l10n/l10n.dart';

/// Segunda línea de la fila: el usuario, o en una tarjeta los últimos 4
/// dígitos (nunca el número completo) y en un documento el nombre.
String? entrySubtitle(VaultEntry entry) {
  String? nonEmpty(String? v) => (v == null || v.isEmpty) ? null : v;
  switch (entry.type) {
    case VaultEntryType.card:
      final digits = (entry.fields[EntryFields.cardNumber] ?? '').replaceAll(
        RegExp(r'\D'),
        '',
      );
      final last4 = digits.length >= 4
          ? '•••• ${digits.substring(digits.length - 4)}'
          : null;
      return [
        ?last4,
        ?nonEmpty(entry.fields[EntryFields.cardHolder]),
      ].join(' · ').ifEmptyNull;
    case VaultEntryType.document:
      return nonEmpty(entry.fields[EntryFields.docName]);
    default:
      return nonEmpty(entry.fields[EntryFields.username]);
  }
}

extension on String {
  String? get ifEmptyNull => isEmpty ? null : this;
}

/// Fila de lista — icono/inicial + título + subtítulo + chevron, ver
/// docs/design/README.md.
class EntryTile extends StatelessWidget {
  final VaultEntry entry;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  /// `null` fuera del modo selección.
  final bool? selected;

  /// Ícono del sitio de la entrada, si hay (ADR 0029).
  final Uint8List? siteIcon;

  const EntryTile({
    super.key,
    required this.entry,
    required this.onTap,
    required this.onLongPress,
    this.selected,
    this.siteIcon,
  });

  @override
  Widget build(BuildContext context) {
    final subtitle = entrySubtitle(entry);

    return Material(
      color: context.palette.bgSurface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        onLongPress: onLongPress,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: LockspireSpacing.md,
            vertical: LockspireSpacing.smMd,
          ),
          child: Row(
            children: [
              EntryAvatar(entry: entry, siteIcon: siteIcon),
              const SizedBox(width: LockspireSpacing.smMd),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.title,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    if (subtitle != null)
                      Text(
                        subtitle,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                  ],
                ),
              ),
              if (selected != null)
                Checkbox(value: selected, onChanged: (_) => onTap())
              else
                Icon(
                  Icons.chevron_right,
                  color: context.palette.textPlaceholder,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class VaultEmptyState extends StatelessWidget {
  final bool hasQuery;

  const VaultEmptyState({super.key, required this.hasQuery});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(LockspireSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              hasQuery ? Icons.search_off : Icons.password_outlined,
              size: 48,
              color: context.palette.textPlaceholder,
            ),
            const SizedBox(height: LockspireSpacing.md),
            Text(
              hasQuery ? context.l10n.vaultNoResults : context.l10n.vaultEmpty,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            if (!hasQuery) ...[
              const SizedBox(height: LockspireSpacing.xs),
              Text(
                context.l10n.vaultEmptyHint,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
