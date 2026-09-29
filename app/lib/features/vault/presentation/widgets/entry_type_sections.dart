// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Gabriel Ángel Montoya Rico

import 'package:flutter/material.dart';

import '../../../../design/lockspire_spacing.dart';
import '../../domain/entities/entry_fields.dart';
import 'entry_form_fields.dart';
import 'package:lockspire/l10n/l10n.dart';

/// Campos fijos de una tarjeta (ADR 0025): número, CVV y PIN ocultos, con
/// mostrar y copiar. [fields] son los controladores del formulario por key.
class CardFieldsSection extends StatelessWidget {
  final Map<String, TextEditingController> fields;
  final CopyValue onCopy;

  const CardFieldsSection({
    super.key,
    required this.fields,
    required this.onCopy,
  });

  @override
  Widget build(BuildContext context) {
    const gap = SizedBox(height: LockspireSpacing.md);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SecretField(
          controller: fields[EntryFields.cardNumber]!,
          label: context.l10n.fieldCardNumber,
          keyboardType: TextInputType.number,
          onCopy: onCopy,
        ),
        gap,
        CopyableField(
          controller: fields[EntryFields.cardHolder]!,
          label: context.l10n.fieldCardHolder,
          onCopy: onCopy,
        ),
        gap,
        CopyableField(
          controller: fields[EntryFields.cardExpiry]!,
          label: context.l10n.fieldExpiry,
          hint: context.l10n.fieldCardExpiryHint,
          keyboardType: TextInputType.datetime,
          onCopy: onCopy,
        ),
        gap,
        SecretField(
          controller: fields[EntryFields.cardCvv]!,
          label: context.l10n.fieldCvv,
          keyboardType: TextInputType.number,
          onCopy: onCopy,
        ),
        gap,
        SecretField(
          controller: fields[EntryFields.cardPin]!,
          label: context.l10n.fieldPin,
          keyboardType: TextInputType.number,
          onCopy: onCopy,
        ),
      ],
    );
  }
}

/// Campos fijos de un documento (ADR 0025): número, nombre y fechas.
class DocumentFieldsSection extends StatelessWidget {
  final Map<String, TextEditingController> fields;
  final CopyValue onCopy;

  const DocumentFieldsSection({
    super.key,
    required this.fields,
    required this.onCopy,
  });

  @override
  Widget build(BuildContext context) {
    const gap = SizedBox(height: LockspireSpacing.md);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CopyableField(
          controller: fields[EntryFields.docNumber]!,
          label: context.l10n.fieldDocNumber,
          onCopy: onCopy,
        ),
        gap,
        CopyableField(
          controller: fields[EntryFields.docName]!,
          label: context.l10n.fieldDocName,
          onCopy: onCopy,
        ),
        for (final (key, label) in [
          (EntryFields.docBirthDate, context.l10n.fieldBirthDate),
          (EntryFields.docIssued, context.l10n.fieldIssued),
          (EntryFields.docExpiry, context.l10n.fieldExpiry),
        ]) ...[
          gap,
          CopyableField(
            controller: fields[key]!,
            label: label,
            hint: context.l10n.fieldDateHint,
            keyboardType: TextInputType.datetime,
            onCopy: onCopy,
          ),
        ],
      ],
    );
  }
}
