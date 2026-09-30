// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Gabriel Ángel Montoya Rico

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../domain/entities/vault.dart';
import '../domain/entities/vault_entry.dart';
import 'providers/clock_provider.dart';
import 'vault_session_controller.dart';

part 'vault_entries_controller.g.dart';

@Riverpod(keepAlive: true)
VaultEntriesController vaultEntriesController(Ref ref) =>
    VaultEntriesController(ref);

/// Operaciones sobre las entradas de la bóveda desbloqueada. Separado de
/// `VaultSessionController`, que solo gestiona la sesión (revisión
/// 2026-09-25, hallazgo A1). La regla de negocio está en el dominio
/// (`Vault.withEntry…`, A2); acá solo se describe el cambio y se guarda
/// con [VaultSessionController.updateVault], que lo aplica sobre la bóveda
/// vigente y en fila con las demás escrituras.
///
/// Sin bóveda desbloqueada, las operaciones no hacen nada. Pueden lanzar
/// `VaultWriteConflictException` (ver `updateVault`).
class VaultEntriesController {
  final Ref _ref;

  VaultEntriesController(this._ref);

  /// Agrega una entrada nueva de tipo contraseña.
  Future<void> addEntry({
    required String title,
    VaultEntryType type = VaultEntryType.password,
    Map<String, String> fields = const {},
  }) => _save(
    (vault) => vault.withEntryAdded(
      VaultEntry.create(title: title, type: type, fields: fields),
    ),
  );

  /// Agrega varias entradas de una vez (p. ej. una importación, ver
  /// `VaultImportSource`).
  Future<void> importEntries(List<VaultEntry> entries) =>
      _save((vault) => vault.withEntriesAdded(entries));

  Future<void> updateEntry({
    required String id,
    required String title,
    required Map<String, String> fields,
  }) => _save(
    (vault) => vault.withEntryUpdated(
      id: id,
      title: title,
      fields: fields,
      now: _now(),
    ),
  );

  /// Cambia un campo y guarda el valor anterior en su historial, ver
  /// `Vault.withFieldReplaced`.
  Future<void> replaceField({
    required String id,
    required String field,
    required String value,
  }) => _save(
    (vault) => vault.withFieldReplaced(
      id: id,
      field: field,
      value: value,
      now: _now(),
    ),
  );

  /// Borrado suave (tombstone), ver `Vault.withEntryDeleted`.
  Future<void> deleteEntry(String id) =>
      _save((vault) => vault.withEntryDeleted(id, now: _now()));

  /// Elimina varias entradas en un solo guardado (y una sola sync).
  Future<void> deleteEntries(Set<String> ids) =>
      _save((vault) => vault.withEntriesDeleted(ids, now: _now()));

  DateTime _now() => _ref.read(clockProvider)().toUtc();

  Future<void> _save(Vault Function(Vault current) change) =>
      _ref.read(vaultSessionControllerProvider.notifier).updateVault(change);
}
