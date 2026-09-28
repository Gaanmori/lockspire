// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Lockspire

import 'package:flutter/material.dart';
import '../../../../design/lockspire_colors.dart';
import '../../../../design/lockspire_spacing.dart';
import '../../domain/entities/entry_fields.dart';
import '../../domain/entities/vault_entry.dart';
import 'entry_type_label.dart';

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

  const EntryTile({
    super.key,
    required this.entry,
    required this.onTap,
    required this.onLongPress,
    this.selected,
  });

  @override
  Widget build(BuildContext context) {
    final subtitle = entrySubtitle(entry);
    final initial = entry.title.isNotEmpty ? entry.title[0].toUpperCase() : '?';
    final isLogin = entry.type == VaultEntryType.password;

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
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: context.palette.bgSurfaceSubtle,
                  shape: BoxShape.circle,
                ),
                child: isLogin
                    ? Text(
                        initial,
                        style: TextStyle(
                          color: context.palette.accentDefault,
                          fontWeight: FontWeight.w700,
                        ),
                      )
                    : Icon(
                        entry.type.icon,
                        size: 20,
                        color: context.palette.accentDefault,
                      ),
              ),
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
              hasQuery
                  ? 'No se encontraron resultados'
                  : 'Todavía no ha guardado ninguna contraseña',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            if (!hasQuery) ...[
              const SizedBox(height: LockspireSpacing.xs),
              Text(
                'Toque el botón "+" para agregar la primera',
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
