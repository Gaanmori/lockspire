// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Lockspire

/// Tipo de una entrada de bóveda, ver formato v1 (docs/adr/0004-formato-boveda-v1.md).
enum VaultEntryType { password, passkey, note }

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
  final bool deleted;
  final DateTime? deletedAt;
  final Map<String, String> fields;

  const VaultEntry({
    required this.id,
    required this.type,
    required this.title,
    required this.createdAt,
    required this.modifiedAt,
    this.deleted = false,
    this.deletedAt,
    this.fields = const {},
  });

  VaultEntry copyWith({
    String? title,
    DateTime? modifiedAt,
    bool? deleted,
    DateTime? deletedAt,
    Map<String, String>? fields,
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
  };

  factory VaultEntry.fromJson(Map<String, dynamic> json) {
    return VaultEntry(
      id: json['id'] as String,
      type: VaultEntryType.values.byName(json['type'] as String),
      title: json['title'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      modifiedAt: DateTime.parse(json['modified_at'] as String),
      deleted: json['deleted'] as bool? ?? false,
      deletedAt: json['deleted_at'] == null
          ? null
          : DateTime.parse(json['deleted_at'] as String),
      fields: Map<String, String>.from(json['fields'] as Map? ?? const {}),
    );
  }
}
