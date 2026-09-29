// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Gabriel Ángel Montoya Rico

import '../../vault/domain/entities/entry_fields.dart';
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
/// Ordena [entries] (solo contraseñas no borradas): primero las que tienen
/// guardado exactamente [packageName] como app (ADR 0025), después las que
/// parecen corresponderle por texto en el título o los sitios, y al final
/// el resto — nunca **oculta** nada:
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

  final visible = entries
      .where((e) => !e.deleted && e.type == VaultEntryType.password)
      .toList();

  bool linked(VaultEntry entry) => entry.apps.contains(packageName);
  bool resembles(VaultEntry entry) {
    if (tokens.isEmpty) return false;
    final haystack = '${entry.title} ${entry.urls.join(' ')}'.toLowerCase();
    return tokens.any(haystack.contains);
  }

  final exact = <VaultEntry>[];
  final matched = <VaultEntry>[];
  final rest = <VaultEntry>[];
  for (final entry in visible) {
    (linked(entry)
            ? exact
            : resembles(entry)
            ? matched
            : rest)
        .add(entry);
  }
  return [...exact, ...matched, ...rest];
}
