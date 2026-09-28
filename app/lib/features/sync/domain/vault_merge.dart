// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Lockspire

import 'package:lockspire/features/vault/domain/entities/vault.dart';
import 'package:lockspire/features/vault/domain/entities/vault_entry.dart';

/// Resultado de un merge de 3 vías — siempre completo: cualquier choque
/// real entre entrada local y remota se resuelve automáticamente por campo
/// (ver docs/adr/0009-merge-automatico-por-campo.md), nunca queda nada
/// pendiente de que el usuario decida.
class MergeAnalysis {
  final Vault autoMerged;

  /// Entradas completas resueltas automáticamente porque solo cambió un
  /// lado (o fue un caso de tombstone) — no implica que hubo un choque de
  /// campo real, ver [fieldConflictsResolved] para eso.
  final int autoResolvedCount;

  /// Cuántos campos individuales tuvieron un choque real (mismo campo,
  /// valores distintos en ambos lados) y se resolvieron automáticamente
  /// por `modifiedAt` — el valor perdedor queda en
  /// `VaultEntry.fieldHistory`, nunca se pierde en silencio.
  final int fieldConflictsResolved;

  const MergeAnalysis({
    required this.autoMerged,
    required this.autoResolvedCount,
    required this.fieldConflictsResolved,
  });
}

/// Analiza un merge de 3 vías entre [local] y [remote], usando [ancestor]
/// (el último snapshot sincronizado con éxito, o `null` si no hay uno
/// todavía — se trata como si todo fuera nuevo) como base de comparación.
///
/// Puro, sin I/O — ver docs/adr/0006-modelo-resolucion-conflictos.md (LWW
/// por entrada + tombstones) y docs/adr/0009-merge-automatico-por-campo.md
/// (qué pasa cuando ambos lados cambiaron la misma entrada: merge por
/// campo, nunca un picker manual).
MergeAnalysis mergeVaults({
  required Vault? ancestor,
  required Vault local,
  required Vault remote,
}) {
  final ancestorById = {for (final e in ancestor?.entries ?? const []) e.id: e};
  final localById = {for (final e in local.entries) e.id: e};
  final remoteById = {for (final e in remote.entries) e.id: e};
  final allIds = {...ancestorById.keys, ...localById.keys, ...remoteById.keys};

  final merged = <VaultEntry>[];
  var autoResolvedCount = 0;
  var fieldConflictsResolved = 0;

  for (final id in allIds) {
    final a = ancestorById[id];
    final l = localById[id];
    final r = remoteById[id];

    if (l == null && r == null) continue;
    if (l == null) {
      merged.add(r!);
      continue;
    }
    if (r == null) {
      merged.add(l);
      continue;
    }

    if (_sameContent(l, r)) {
      merged.add(l);
      continue;
    }

    final localChanged =
        a == null ||
        l.modifiedAt.isAfter(a.modifiedAt) ||
        l.deleted != a.deleted;
    final remoteChanged =
        a == null ||
        r.modifiedAt.isAfter(a.modifiedAt) ||
        r.deleted != a.deleted;

    if (localChanged && !remoteChanged) {
      merged.add(l);
      autoResolvedCount++;
      continue;
    }
    if (remoteChanged && !localChanged) {
      merged.add(r);
      autoResolvedCount++;
      continue;
    }

    // Cambiaron los dos — tombstones primero (ADR 0006 paso 4): una
    // edición posterior a un borrado "revive" la entrada.
    final localDeletedAt = l.deletedAt ?? l.modifiedAt;
    final remoteDeletedAt = r.deletedAt ?? r.modifiedAt;
    if (l.deleted && !r.deleted && r.modifiedAt.isAfter(localDeletedAt)) {
      merged.add(r);
      autoResolvedCount++;
      continue;
    }
    if (r.deleted && !l.deleted && l.modifiedAt.isAfter(remoteDeletedAt)) {
      merged.add(l);
      autoResolvedCount++;
      continue;
    }
    if (l.deleted && r.deleted) {
      merged.add(l);
      autoResolvedCount++;
      continue;
    }

    // Cambiaron los dos de verdad, ninguno es tombstone-vs-edición: merge
    // por campo (ADR 0009) — nunca un conflicto que el usuario deba
    // resolver a mano.
    final fieldMerge = _mergeEntryFields(ancestor: a, local: l, remote: r);
    merged.add(fieldMerge.entry);
    autoResolvedCount++;
    fieldConflictsResolved += fieldMerge.conflictCount;
  }

  return MergeAnalysis(
    autoMerged: Vault(
      vaultId: local.vaultId,
      schemaVersion: local.schemaVersion,
      folders: local.folders,
      entries: merged,
      // ADR 0023: si la nube cambió la nube de la bóveda (una mudanza hecha
      // en otro dispositivo), gana la nube; si no, se queda la local.
      syncHome: remote.syncHome != ancestor?.syncHome
          ? remote.syncHome ?? local.syncHome
          : local.syncHome,
    ),
    autoResolvedCount: autoResolvedCount,
    fieldConflictsResolved: fieldConflictsResolved,
  );
}

class _FieldMergeResult {
  final VaultEntry entry;
  final int conflictCount;

  const _FieldMergeResult({required this.entry, required this.conflictCount});
}

/// Merge por campo de dos versiones de la misma entrada que cambiaron
/// distinto desde [ancestor] (o sin ancestro — primera divergencia). Ver
/// docs/adr/0009-merge-automatico-por-campo.md para el modelo completo y
/// los cuatro puntos documentados ahí (recencia a nivel de entrada, no de
/// campo; ausencia de campo como valor más; dedupe de historial antes del
/// tope; `fieldHistory` solo se combina de ambos lados en un choque real).
_FieldMergeResult _mergeEntryFields({
  required VaultEntry? ancestor,
  required VaultEntry local,
  required VaultEntry remote,
}) {
  final keys = <String>{
    titleFieldKey,
    ...?ancestor?.fields.keys,
    ...local.fields.keys,
    ...remote.fields.keys,
  };

  String? valueOf(VaultEntry? entry, String key) =>
      key == titleFieldKey ? entry?.title : entry?.fields[key];

  final localIsNewer = local.modifiedAt.isAfter(remote.modifiedAt);
  final remoteIsNewer = remote.modifiedAt.isAfter(local.modifiedAt);

  final mergedFields = <String, String>{};
  String? mergedTitle;
  final mergedHistory = <String, List<FieldHistoryRecord>>{};
  var conflictCount = 0;

  for (final key in keys) {
    final aVal = valueOf(ancestor, key);
    final lVal = valueOf(local, key);
    final rVal = valueOf(remote, key);

    String? winner;
    List<FieldHistoryRecord> winnerHistory;

    if (lVal == rVal) {
      // Sin conflicto — incluye "ninguno cambió este campo" y "los dos lo
      // vaciaron". Se conserva el historial de cualquiera de los dos lados
      // (acá arbitrariamente el local) — decisión explícita, ver ADR 0009
      // punto 4: el historial es diagnóstico, no autoritativo.
      winner = lVal;
      winnerHistory = local.fieldHistory[key] ?? const [];
    } else if (lVal == aVal) {
      // Cambió solo remoto.
      winner = rVal;
      winnerHistory = remote.fieldHistory[key] ?? const [];
    } else if (rVal == aVal) {
      // Cambió solo local.
      winner = lVal;
      winnerHistory = local.fieldHistory[key] ?? const [];
    } else {
      // Conflicto real de campo (Nivel 2) — ninguno coincide con el
      // ancestro y difieren entre sí. Gana el de `modifiedAt` más
      // reciente; empate exacto se desempata por el string del valor
      // (determinista, sin importar qué dispositivo corra el merge).
      conflictCount++;
      final thisLocalWins =
          localIsNewer ||
          (!remoteIsNewer && (lVal ?? '').compareTo(rVal ?? '') > 0);
      winner = thisLocalWins ? lVal : rVal;
      final loser = thisLocalWins ? rVal : lVal;

      final combined = <FieldHistoryRecord>[
        ...(local.fieldHistory[key] ?? const []),
        ...(remote.fieldHistory[key] ?? const []),
        if (loser != null && loser.isNotEmpty)
          FieldHistoryRecord(value: loser, replacedAt: DateTime.now().toUtc()),
      ];
      winnerHistory = _dedupeAndCapHistory(combined);
    }

    if (key == titleFieldKey) {
      mergedTitle = winner;
    } else if (winner != null) {
      mergedFields[key] = winner;
    }
    if (winnerHistory.isNotEmpty) {
      mergedHistory[key] = winnerHistory;
    }
  }

  final entry = VaultEntry(
    id: local.id,
    type: local.type,
    title: mergedTitle ?? local.title,
    createdAt: local.createdAt,
    modifiedAt: localIsNewer ? local.modifiedAt : remote.modifiedAt,
    fields: mergedFields,
    fieldHistory: mergedHistory,
  );

  return _FieldMergeResult(entry: entry, conflictCount: conflictCount);
}

/// Deduplica por valor (quedándose con el registro de `replacedAt` más
/// reciente de cada valor repetido) **antes** de ordenar y cortar al tope
/// — así mergear la misma entrada varias veces seguidas no va repitiendo
/// el mismo valor histórico en vez de acumular valores distintos (ADR
/// 0009, punto 3).
List<FieldHistoryRecord> _dedupeAndCapHistory(
  List<FieldHistoryRecord> records,
) {
  final byValue = <String, FieldHistoryRecord>{};
  for (final record in records) {
    final existing = byValue[record.value];
    if (existing == null || record.replacedAt.isAfter(existing.replacedAt)) {
      byValue[record.value] = record;
    }
  }
  final sorted = byValue.values.toList()
    ..sort((a, b) => b.replacedAt.compareTo(a.replacedAt));
  return sorted.take(maxFieldHistoryPerField).toList();
}

bool _sameContent(VaultEntry a, VaultEntry b) {
  return a.title == b.title &&
      a.deleted == b.deleted &&
      _mapsEqual(a.fields, b.fields);
}

bool _mapsEqual(Map<String, String> a, Map<String, String> b) {
  if (a.length != b.length) return false;
  for (final entry in a.entries) {
    if (b[entry.key] != entry.value) return false;
  }
  return true;
}
