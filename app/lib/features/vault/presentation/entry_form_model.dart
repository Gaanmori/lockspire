// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Gabriel Ángel Montoya Rico

import 'package:flutter/widgets.dart';

import '../application/password_generation_settings.dart';
import '../domain/entities/entry_fields.dart';
import '../domain/entities/vault_entry.dart';
import 'widgets/entry_form_fields.dart';

/// Lo que se escribe en el formulario de una entrada y cómo se vuelve sus
/// campos (revisión 2026-09-30, A15). Separado de la pantalla: no dibuja
/// nada, y se puede probar sin montarla.
class EntryFormModel {
  final VaultEntryType type;

  /// Los campos con que se abrió (vacío al crear).
  final Map<String, String> initial;

  final TextEditingController title;
  final TextEditingController notes;

  /// Los campos propios del tipo: usuario y contraseña, los de la tarjeta o
  /// los del documento.
  final Map<String, TextEditingController> fixed;

  final List<TextEditingController> urls;
  final List<TextEditingController> apps;
  final List<CustomFieldDraft> custom;

  PasswordGenerationSettings generation;

  EntryFormModel._({
    required this.type,
    required this.initial,
    required this.title,
    required this.notes,
    required this.fixed,
    required this.urls,
    required this.apps,
    required this.custom,
    required this.generation,
  });

  /// [entry] nulo: una entrada nueva de tipo [type].
  factory EntryFormModel({VaultEntry? entry, required VaultEntryType type}) {
    final resolvedType = entry?.type ?? type;
    final initial = entry?.fields ?? const <String, String>{};
    final urls = repeatedValues(initial, EntryFields.url);
    return EntryFormModel._(
      type: resolvedType,
      initial: initial,
      title: TextEditingController(text: entry?.title ?? ''),
      notes: TextEditingController(text: initial[EntryFields.notes] ?? ''),
      fixed: {
        for (final key in fixedKeysFor(resolvedType))
          key: TextEditingController(text: initial[key]),
      },
      urls: [
        for (final url in urls) TextEditingController(text: url),
        // Una contraseña nueva arranca con un sitio vacío, listo para
        // escribir.
        if (urls.isEmpty && resolvedType == VaultEntryType.password)
          TextEditingController(),
      ],
      apps: [
        for (final app in repeatedValues(initial, EntryFields.app))
          TextEditingController(text: app),
      ],
      custom: [
        for (final field in customFieldsOf(initial))
          CustomFieldDraft(
            name: field.name,
            hidden: field.hidden,
            value: field.value,
          ),
      ],
      generation: entry == null
          ? PasswordGenerationSettings.forNewEntry
          : PasswordGenerationSettings.fromFields(entry.fields),
    );
  }

  /// Keys con campo propio en el formulario, según el tipo.
  static List<String> fixedKeysFor(VaultEntryType type) => switch (type) {
    VaultEntryType.card => const [
      EntryFields.cardNumber,
      EntryFields.cardHolder,
      EntryFields.cardExpiry,
      EntryFields.cardCvv,
      EntryFields.cardPin,
    ],
    VaultEntryType.document => const [
      EntryFields.docNumber,
      EntryFields.docName,
      EntryFields.docBirthDate,
      EntryFields.docIssued,
      EntryFields.docExpiry,
    ],
    _ => const [EntryFields.username, EntryFields.password],
  };

  TextEditingController get password => fixed[EntryFields.password]!;

  /// Los campos a guardar: parte de los que tenía la entrada para no perder
  /// los que el formulario no maneja, quita los que sí maneja y agrega lo
  /// que hay en pantalla.
  Map<String, String> toFields() {
    bool managed(String key) =>
        fixed.containsKey(key) ||
        key == EntryFields.notes ||
        repeatedIndex(EntryFields.url, key) != null ||
        repeatedIndex(EntryFields.app, key) != null ||
        CustomField.fromEntry(key, '') != null ||
        key == PasswordGenerationSettings.modeFieldKey ||
        key == PasswordGenerationSettings.lengthFieldKey;

    return {
      for (final MapEntry(:key, :value) in initial.entries)
        if (!managed(key)) key: value,
      for (final MapEntry(:key, value: controller) in fixed.entries)
        if (controller.text.isNotEmpty) key: controller.text,
      ...repeatedFields(EntryFields.url, urls.map((c) => c.text)),
      ...repeatedFields(EntryFields.app, apps.map((c) => c.text)),
      for (final draft in custom)
        if (draft.value.text.isNotEmpty)
          CustomField(
            name: draft.name,
            value: draft.value.text,
            hidden: draft.hidden,
          ).key: draft.value.text,
      if (notes.text.isNotEmpty) EntryFields.notes: notes.text,
      if (type == VaultEntryType.password) ...generation.toFields(),
    };
  }

  void dispose() {
    for (final controller in [
      title,
      notes,
      ...fixed.values,
      ...urls,
      ...apps,
      for (final draft in custom) draft.value,
    ]) {
      controller.dispose();
    }
  }
}
