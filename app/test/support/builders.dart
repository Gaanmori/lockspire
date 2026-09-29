// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Gabriel Ángel Montoya Rico

import 'package:lockspire/features/vault/domain/entities/vault_entry.dart';

/// Fecha fija de los datos de prueba: los tests no dependen del reloj.
final testEpoch = DateTime.utc(2026, 1, 1);

/// Una entrada de bóveda para tests, con valores por defecto razonables.
///
/// Solo se pasa lo que importa para el test ("una contraseña de
/// ejemplo.com", "una entrada borrada"): el resto no distrae. `id` y
/// `title` se completan entre sí si falta uno. [username], [password] y
/// [url] son atajos de los campos más usados y se suman a [fields].
VaultEntry anEntry({
  String? id,
  String? title,
  VaultEntryType type = VaultEntryType.password,
  String? username,
  String? password,
  String? url,
  Map<String, String> fields = const {},
  Map<String, List<FieldHistoryRecord>> fieldHistory = const {},
  DateTime? createdAt,
  DateTime? modifiedAt,
  bool deleted = false,
  DateTime? deletedAt,
}) {
  final resolvedId = id ?? title ?? 'entry';
  return VaultEntry(
    id: resolvedId,
    type: type,
    title: title ?? resolvedId,
    createdAt: createdAt ?? testEpoch,
    modifiedAt: modifiedAt ?? createdAt ?? testEpoch,
    deleted: deleted,
    deletedAt: deletedAt,
    fields: {
      ...fields,
      'username': ?username,
      'password': ?password,
      'url': ?url,
    },
    fieldHistory: fieldHistory,
  );
}
