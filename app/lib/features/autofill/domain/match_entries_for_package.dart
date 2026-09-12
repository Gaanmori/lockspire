// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Lockspire

import '../../vault/domain/entities/vault_entry.dart';

/// Segmentos de un nombre de paquete Android demasiado genéricos para
/// contar como señal de coincidencia (aparecen en casi cualquier paquete,
/// ej. `com.frisby.frisby` → `com` no dice nada de cuál app es).
const _genericPackageSegments = {
  'com',
  'org',
  'net',
  'io',
  'co',
  'app',
  'android',
  'www',
};

/// Heurística de matching app↔entrada para autofill (ADR 0011) — sin UI
/// de vinculación manual en esta pasada, confirmado con el usuario.
///
/// Ordena [entries] (excluyendo las borradas) con las que parecen
/// corresponder a [packageName] primero, según coincidencia de texto
/// contra el título o la URL de la entrada — nunca **oculta** el resto:
/// si no hay ninguna coincidencia clara, devuelve la lista completa
/// igual, en su orden original, para que el usuario elija a mano.
List<VaultEntry> matchEntriesForPackage({
  required List<VaultEntry> entries,
  required String packageName,
}) {
  final tokens = packageName
      .toLowerCase()
      .split('.')
      .where((segment) => segment.length >= 3)
      .where((segment) => !_genericPackageSegments.contains(segment))
      .toSet();

  final visible = entries.where((e) => !e.deleted).toList();
  if (tokens.isEmpty) return visible;

  bool matches(VaultEntry entry) {
    final haystack = '${entry.title} ${entry.fields['url'] ?? ''}'
        .toLowerCase();
    return tokens.any(haystack.contains);
  }

  final matched = <VaultEntry>[];
  final rest = <VaultEntry>[];
  for (final entry in visible) {
    (matches(entry) ? matched : rest).add(entry);
  }
  return [...matched, ...rest];
}
