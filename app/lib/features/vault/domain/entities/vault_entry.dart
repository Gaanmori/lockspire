// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Gabriel Ángel Montoya Rico

import 'package:uuid/uuid.dart';

/// Tipo de una entrada de bóveda, ver formato v1 (docs/adr/0004-formato-boveda-v1.md).
/// `card` y `document`: ADR 0025.
enum VaultEntryType { password, passkey, note, card, document }

/// Key reservada para tratar `title` como un campo más en el merge por
/// campo (ver docs/adr/0009-merge-automatico-por-campo.md) sin mezclarlo en
/// el mapa [VaultEntry.fields] — el prefijo `$` no puede colisionar con una
/// key real de `fields` (usuario/contraseña/url/notas/etc.).
const titleFieldKey = r'$title';

/// Cuántos valores anteriores se retienen por campo en
/// [VaultEntry.fieldHistory] — acotado a propósito, no versionado
/// ilimitado (ver ADR 0009).
const maxFieldHistoryPerField = 3;

/// Un valor de campo descartado por un merge automático de Nivel 2 (ADR
/// 0009) — se conserva para que el usuario pueda verlo en el detalle de la
/// entrada, nunca se pierde en silencio.
class FieldHistoryRecord {
  final String value;
  final DateTime replacedAt;

  const FieldHistoryRecord({required this.value, required this.replacedAt});

  Map<String, dynamic> toJson() => {
    'value': value,
    'replaced_at': replacedAt.toIso8601String(),
  };

  factory FieldHistoryRecord.fromJson(Map<String, dynamic> json) {
    return FieldHistoryRecord(
      value: json['value'] as String,
      replacedAt: DateTime.parse(json['replaced_at'] as String),
    );
  }
}

/// Una entrada de la bóveda (credencial, passkey o nota).
///
/// Los campos específicos por [type] (usuario, contraseña, URL, etc.) se
/// mantienen en [fields] en vez de una jerarquía de subclases — el schema
/// JSON del formato v1 ya los trata como un mapa de texto libre por tipo.
class VaultEntry {
  final String id;
  final VaultEntryType type;
  final String title;
  final DateTime createdAt;
  final DateTime modifiedAt;

  /// Tombstone de borrado suave: una entrada borrada se marca acá en vez de
  /// quitarse de [Vault.entries], para que un futuro sync sepa propagar el
  /// borrado a otros dispositivos. Ver `sync/domain/vault_merge.dart` para
  /// cómo lo usa el merge (ADR 0006).
  final bool deleted;
  final DateTime? deletedAt;
  final Map<String, String> fields;

  /// Valores descartados por un merge automático de Nivel 2 (ADR 0009),
  /// por key de campo (incluye [titleFieldKey] para el título) — acotado a
  /// [maxFieldHistoryPerField] por campo. Vacío para la enorme mayoría de
  /// las entradas, que nunca tuvieron un choque real.
  final Map<String, List<FieldHistoryRecord>> fieldHistory;

  const VaultEntry({
    required this.id,
    required this.type,
    required this.title,
    required this.createdAt,
    required this.modifiedAt,
    this.deleted = false,
    this.deletedAt,
    this.fields = const {},
    this.fieldHistory = const {},
  });

  /// Crea una entrada nueva (por defecto una contraseña) con id y
  /// timestamps generados.
  factory VaultEntry.create({
    required String title,
    VaultEntryType type = VaultEntryType.password,
    Map<String, String> fields = const {},
    Map<String, List<FieldHistoryRecord>> fieldHistory = const {},
    Uuid uuid = const Uuid(),
  }) {
    final now = DateTime.now().toUtc();
    return VaultEntry(
      id: uuid.v4(),
      type: type,
      title: title,
      createdAt: now,
      modifiedAt: now,
      fields: fields,
      fieldHistory: fieldHistory,
    );
  }

  VaultEntry copyWith({
    String? title,
    DateTime? modifiedAt,
    bool? deleted,
    DateTime? deletedAt,
    Map<String, String>? fields,
    Map<String, List<FieldHistoryRecord>>? fieldHistory,
  }) {
    return VaultEntry(
      id: id,
      type: type,
      title: title ?? this.title,
      createdAt: createdAt,
      modifiedAt: modifiedAt ?? this.modifiedAt,
      deleted: deleted ?? this.deleted,
      deletedAt: deletedAt ?? this.deletedAt,
      fields: fields ?? this.fields,
      fieldHistory: fieldHistory ?? this.fieldHistory,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type.name,
    'title': title,
    'created_at': createdAt.toIso8601String(),
    'modified_at': modifiedAt.toIso8601String(),
    'deleted': deleted,
    'deleted_at': deletedAt?.toIso8601String(),
    'fields': fields,
    if (fieldHistory.isNotEmpty)
      'field_history': {
        for (final entry in fieldHistory.entries)
          entry.key: entry.value.map((r) => r.toJson()).toList(),
      },
  };

  factory VaultEntry.fromJson(Map<String, dynamic> json) {
    final historyJson = json['field_history'] as Map?;
    return VaultEntry(
      id: json['id'] as String,
      // Un tipo que esta versión no conoce se trata como contraseña en vez
      // de impedir abrir la bóveda (ADR 0025).
      type:
          VaultEntryType.values.asNameMap()[json['type'] as String] ??
          VaultEntryType.password,
      title: json['title'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      modifiedAt: DateTime.parse(json['modified_at'] as String),
      deleted: json['deleted'] as bool? ?? false,
      deletedAt: json['deleted_at'] == null
          ? null
          : DateTime.parse(json['deleted_at'] as String),
      fields: Map<String, String>.from(json['fields'] as Map? ?? const {}),
      fieldHistory: historyJson == null
          ? const {}
          : {
              for (final entry in historyJson.entries)
                entry.key as String: (entry.value as List)
                    .map(
                      (r) => FieldHistoryRecord.fromJson(
                        r as Map<String, dynamic>,
                      ),
                    )
                    .toList(),
            },
    );
  }
}
