// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Gabriel Ángel Montoya Rico

import 'package:flutter/material.dart';

import '../../../../design/lockspire_spacing.dart';
import '../../application/password_generation_settings.dart';
import '../../domain/entities/entry_fields.dart';
import '../../domain/entities/vault_entry.dart';
import 'package:lockspire/l10n/l10n.dart';

/// Muestra los valores que un merge automático de Nivel 2 descartó por
/// esta entrada (ADR 0009) — solo lectura, sin botón de restaurar (no se
/// pidió esa funcionalidad, evita alcance extra). Nunca se pierde en
/// silencio un valor perdedor, pero tampoco molesta a nadie que nunca tuvo
/// un choque real: la sección entera no se muestra si `fieldHistory` está
/// vacío (ver el `if` en el `build()` de arriba).
class FieldHistorySection extends StatelessWidget {
  final VaultEntry entry;

  const FieldHistorySection({super.key, required this.entry});

  static String _displayName(AppLocalizations l10n, String key) {
    if (key == titleFieldKey) return l10n.fieldTitle;
    final custom = CustomField.fromEntry(key, '');
    if (custom != null) return custom.name;
    final urlIndex = repeatedIndex(EntryFields.url, key);
    if (urlIndex != null) return l10n.fieldWebsiteN(urlIndex + 1);
    final appIndex = repeatedIndex(EntryFields.app, key);
    if (appIndex != null) return l10n.fieldAppN(appIndex + 1);
    return switch (key) {
      EntryFields.username => l10n.fieldUsername,
      EntryFields.password => l10n.fieldPassword,
      EntryFields.notes => l10n.fieldNotes,
      EntryFields.cardNumber => l10n.fieldCardNumber,
      EntryFields.cardHolder => l10n.fieldCardHolder,
      EntryFields.cardExpiry => l10n.fieldExpiry,
      EntryFields.cardCvv => l10n.fieldCvv,
      EntryFields.cardPin => l10n.fieldPin,
      EntryFields.docNumber => l10n.fieldDocNumber,
      EntryFields.docName => l10n.fieldDocName,
      EntryFields.docBirthDate => l10n.fieldBirthDate,
      EntryFields.docIssued => l10n.fieldIssued,
      EntryFields.docExpiry => l10n.fieldExpiry,
      PasswordGenerationSettings.modeFieldKey => l10n.fieldGenerationMode,
      PasswordGenerationSettings.lengthFieldKey => l10n.fieldGenerationParam,
      _ => key,
    };
  }

  /// Valores que no se muestran en texto plano (contraseñas, CVV, PIN,
  /// número de tarjeta y campos ocultos).
  static bool _isSecret(String key) =>
      EntryFields.secretKeys.contains(key) ||
      key == EntryFields.cardNumber ||
      key.startsWith(EntryFields.hiddenPrefix);

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        title: Text(context.l10n.historyTitle),
        subtitle: Text(context.l10n.historyHint),
        children: [
          for (final field in entry.fieldHistory.entries)
            Padding(
              padding: const EdgeInsets.only(bottom: LockspireSpacing.sm),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _displayName(context.l10n, field.key),
                    style: Theme.of(context).textTheme.labelMedium,
                  ),
                  for (final record in field.value)
                    Text(
                      // La contraseña nunca se muestra en texto plano acá
                      // — mismo criterio de seguridad que el campo del
                      // formulario, sin botón de "revelar" (fuera de
                      // alcance, no se pidió).
                      _isSecret(field.key)
                          ? '•••••••• — ${record.replacedAt.toLocal()}'
                          : '${record.value} — ${record.replacedAt.toLocal()}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
