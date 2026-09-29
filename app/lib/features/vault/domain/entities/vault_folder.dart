// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Gabriel Ángel Montoya Rico

/// Una carpeta usada para organizar entradas dentro de la bóveda.
class VaultFolder {
  final String id;
  final String name;
  final DateTime modifiedAt;

  const VaultFolder({
    required this.id,
    required this.name,
    required this.modifiedAt,
  });

  VaultFolder copyWith({String? name, DateTime? modifiedAt}) {
    return VaultFolder(
      id: id,
      name: name ?? this.name,
      modifiedAt: modifiedAt ?? this.modifiedAt,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'modified_at': modifiedAt.toIso8601String(),
  };

  factory VaultFolder.fromJson(Map<String, dynamic> json) {
    return VaultFolder(
      id: json['id'] as String,
      name: json['name'] as String,
      modifiedAt: DateTime.parse(json['modified_at'] as String),
    );
  }
}
