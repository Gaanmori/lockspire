// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Gabriel Ángel Montoya Rico

import 'package:flutter/material.dart';

import '../../../../design/lockspire_spacing.dart';
import '../../application/password_generation_settings.dart';
import '../../domain/entities/entry_fields.dart';
import '../../domain/entities/vault_entry.dart';
import 'package:lockspire/l10n/l10n.dart';

/// Muestra los valores anteriores de la entrada: los que descartó un merge
/// automático (ADR 0009), los que se importaron y los secretos cambiados al
/// editar o desde el navegador (S20, ADR 0034). Los secretos se pueden
/// copiar, sin mostrarse, para recuperar uno. La sección no aparece si
/// `fieldHistory` está vacío.
class FieldHistorySection extends StatelessWidget {
  final VaultEntry entry;

  /// Copia un valor anterior con el portapapeles protegido: (etiqueta,
  /// valor).
  final Future<void> Function(String label, String value) onCopy;

  const FieldHistorySection({
    super.key,
    required this.entry,
    required this.onCopy,
  });

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
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            // Un secreto nunca se muestra en texto plano
                            // acá; se puede copiar, con el portapapeles
                            // protegido (S4), para recuperarlo (S20).
                            _isSecret(field.key)
                                ? '•••••••• — ${record.replacedAt.toLocal()}'
                                : '${record.value} — '
                                      '${record.replacedAt.toLocal()}',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                        if (_isSecret(field.key))
                          IconButton(
                            icon: const Icon(Icons.copy, size: 18),
                            tooltip: context.l10n.historyCopy,
                            onPressed: () => onCopy(
                              _displayName(context.l10n, field.key),
                              record.value,
                            ),
                          ),
                      ],
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
