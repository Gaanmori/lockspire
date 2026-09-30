// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Gabriel Ángel Montoya Rico

import '../domain/entities/entry_fields.dart';
import '../domain/entities/vault_entry.dart';

/// Las entradas visibles (sin borrar) que coinciden con [query], ordenadas
/// por título sin distinguir mayúsculas. Busca en el título, el usuario, el
/// titular de la tarjeta, el nombre del documento y los sitios.
///
/// Cada título se pasa a minúsculas una sola vez, no en cada comparación
/// del orden (revisión 2026-09-30, P3).
List<VaultEntry> searchEntries(Iterable<VaultEntry> entries, String query) {
  final needle = query.trim().toLowerCase();
  bool contains(String? value) =>
      value?.toLowerCase().contains(needle) ?? false;
  final matching = [
    for (final entry in entries)
      if (!entry.deleted &&
          (needle.isEmpty ||
              contains(entry.title) ||
              contains(entry.fields[EntryFields.username]) ||
              contains(entry.fields[EntryFields.cardHolder]) ||
              contains(entry.fields[EntryFields.docName]) ||
              entry.urls.any(contains)))
        (key: entry.title.toLowerCase(), entry: entry),
  ]..sort((a, b) => a.key.compareTo(b.key));
  return [for (final m in matching) m.entry];
}
