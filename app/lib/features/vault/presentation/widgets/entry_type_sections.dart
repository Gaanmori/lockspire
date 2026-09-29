// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Gabriel Ángel Montoya Rico

import 'package:flutter/material.dart';

import '../../../../design/lockspire_spacing.dart';
import '../../domain/entities/entry_fields.dart';
import 'entry_form_fields.dart';

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
          label: 'Número de tarjeta',
          keyboardType: TextInputType.number,
          onCopy: onCopy,
        ),
        gap,
        CopyableField(
          controller: fields[EntryFields.cardHolder]!,
          label: 'Titular',
          onCopy: onCopy,
        ),
        gap,
        CopyableField(
          controller: fields[EntryFields.cardExpiry]!,
          label: 'Vence',
          hint: 'MM/AA',
          keyboardType: TextInputType.datetime,
          onCopy: onCopy,
        ),
        gap,
        SecretField(
          controller: fields[EntryFields.cardCvv]!,
          label: 'CVV',
          keyboardType: TextInputType.number,
          onCopy: onCopy,
        ),
        gap,
        SecretField(
          controller: fields[EntryFields.cardPin]!,
          label: 'PIN',
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
          label: 'Número',
          onCopy: onCopy,
        ),
        gap,
        CopyableField(
          controller: fields[EntryFields.docName]!,
          label: 'Nombre',
          onCopy: onCopy,
        ),
        for (final (key, label) in const [
          (EntryFields.docBirthDate, 'Fecha de nacimiento'),
          (EntryFields.docIssued, 'Expedido'),
          (EntryFields.docExpiry, 'Vence'),
        ]) ...[
          gap,
          CopyableField(
            controller: fields[key]!,
            label: label,
            hint: 'DD/MM/AAAA',
            keyboardType: TextInputType.datetime,
            onCopy: onCopy,
          ),
        ],
      ],
    );
  }
}
