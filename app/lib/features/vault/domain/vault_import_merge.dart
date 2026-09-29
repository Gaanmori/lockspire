// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Gabriel Ángel Montoya Rico

import 'entities/entry_fields.dart';
import 'entities/vault_entry.dart';

/// Qué agregar de una importación y cuántas se omitieron por repetidas.
class ImportSelection {
  final List<VaultEntry> toAdd;
  final int skipped;

  const ImportSelection({required this.toAdd, required this.skipped});
}

/// Importar nunca duplica (ADR 0027): se omiten las entradas cuyo `id` ya
/// existe (un respaldo de esta misma bóveda) y las que coinciden en tipo,
/// título, usuario, contraseña y número con una entrada viva, o con otra
/// del mismo archivo. Importar dos veces el mismo archivo no agrega nada.
ImportSelection selectEntriesToImport({
  required Iterable<VaultEntry> existing,
  required Iterable<VaultEntry> incoming,
}) {
  final ids = {for (final e in existing) e.id};
  final seen = {
    for (final e in existing)
      if (!e.deleted) _identity(e),
  };
  final toAdd = <VaultEntry>[];
  var skipped = 0;
  for (final entry in incoming) {
    if (entry.deleted) continue;
    if (ids.contains(entry.id) || !seen.add(_identity(entry))) {
      skipped++;
      continue;
    }
    ids.add(entry.id);
    toAdd.add(entry);
  }
  return ImportSelection(toAdd: toAdd, skipped: skipped);
}

String _identity(VaultEntry e) {
  String f(String key) => (e.fields[key] ?? '').trim();
  return [
    e.type.name,
    e.title.trim().toLowerCase(),
    f(EntryFields.username).toLowerCase(),
    f(EntryFields.password),
    f(EntryFields.cardNumber).replaceAll(RegExp(r'\s'), ''),
    f(EntryFields.docNumber),
  ].join('\u0000');
}
