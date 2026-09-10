// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Lockspire

import 'package:uuid/uuid.dart';

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

  /// Tombstone de borrado suave: una entrada borrada se marca acá en vez de
  /// quitarse de [Vault.entries], para que un futuro sync sepa propagar el
  /// borrado a otros dispositivos.
  ///
  /// Restricción de diseño para el ADR 0006 (merge automático), todavía sin
  /// escribir: este campo solo es directamente reusable por ese merge si
  /// termina siendo last-write-wins por entrada (comparando [modifiedAt]/
  /// [deletedAt] entrada por entrada) — no un diff estructural del archivo
  /// completo. No se debe asumir resuelto hasta que ese ADR se escriba.
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

  /// Crea una entrada nueva de tipo [VaultEntryType.password] (único tipo
  /// que cubre esta pasada, ver docs/STATE.md — Fase 5) con id y timestamps
  /// generados.
  factory VaultEntry.create({
    required String title,
    Map<String, String> fields = const {},
    Uuid uuid = const Uuid(),
  }) {
    final now = DateTime.now().toUtc();
    return VaultEntry(
      id: uuid.v4(),
      type: VaultEntryType.password,
      title: title,
      createdAt: now,
      modifiedAt: now,
      fields: fields,
    );
  }

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
