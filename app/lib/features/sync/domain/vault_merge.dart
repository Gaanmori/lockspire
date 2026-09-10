// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Lockspire

import 'package:lockspire/features/vault/domain/entities/vault.dart';
import 'package:lockspire/features/vault/domain/entities/vault_entry.dart';

/// Una entrada que cambió distinto en ambos lados desde el ancestro común
/// — ni un tombstone-vs-edición, un conflicto real que solo puede resolver
/// el usuario (ver docs/adr/0006-modelo-resolucion-conflictos.md).
///
/// [remote].id siempre es igual a [local].id — por construcción, ver
/// [mergeVaults].
class EntryConflict {
  final VaultEntry local;
  final VaultEntry remote;

  const EntryConflict({required this.local, required this.remote});
}

/// Resultado de analizar un merge de 3 vías — no necesariamente completo:
/// [autoMerged] tiene todo lo que se pudo resolver solo, pero le faltan
/// las entradas de [conflicts] (ver [applyConflictResolutions]).
class MergeAnalysis {
  final Vault autoMerged;
  final List<EntryConflict> conflicts;
  final int autoResolvedCount;

  const MergeAnalysis({
    required this.autoMerged,
    required this.conflicts,
    required this.autoResolvedCount,
  });

  bool get hasConflicts => conflicts.isNotEmpty;
}

/// Analiza un merge de 3 vías entre [local] y [remote], usando [ancestor]
/// (el último snapshot sincronizado con éxito, o `null` si no hay uno
/// todavía — se trata como si todo fuera nuevo) como base de comparación.
///
/// Puro, sin I/O — ver docs/adr/0006-modelo-resolucion-conflictos.md para
/// el modelo (LWW por entrada + tombstones + conflicto real solo si
/// cambiaron los dos lados de verdad). Los conflictos reales no se deciden
/// acá — quedan en [MergeAnalysis.conflicts] para que el usuario elija
/// (ver `SyncVaultUseCase.completeMerge`).
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
  final conflicts = <EntryConflict>[];
  var autoResolvedCount = 0;

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

    // Conflicto real: ni uno es tombstone-vs-edición, contenido distinto
    // en ambos lados — no se decide acá.
    conflicts.add(EntryConflict(local: l, remote: r));
  }

  return MergeAnalysis(
    autoMerged: Vault(
      vaultId: local.vaultId,
      schemaVersion: local.schemaVersion,
      folders: local.folders,
      entries: merged,
    ),
    conflicts: conflicts,
    autoResolvedCount: autoResolvedCount,
  );
}

/// Inserta en [autoMerged] la entrada que el usuario eligió para cada
/// conflicto (por `id`), **conservando el id original** — a diferencia de
/// un patrón "mantener ambas", acá no se duplica ninguna entrada.
Vault applyConflictResolutions(
  Vault autoMerged,
  Map<String, VaultEntry> resolutions,
) {
  return autoMerged.copyWith(
    entries: [...autoMerged.entries, ...resolutions.values],
  );
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
