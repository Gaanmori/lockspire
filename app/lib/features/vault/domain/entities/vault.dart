// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Lockspire

import 'dart:convert';
import 'dart:typed_data';

import 'vault_entry.dart';
import 'vault_folder.dart';

/// Agregado raíz del dominio: el contenido desencriptado de una bóveda.
///
/// Corresponde 1:1 al payload JSON descrito en
/// docs/adr/0004-formato-boveda-v1.md. [vaultId] debe coincidir con el
/// `vault_id` del header del archivo (ver [VaultHeader] en vault_storage_port.dart).
class Vault {
  final String vaultId;
  final int schemaVersion;
  final List<VaultFolder> folders;
  final List<VaultEntry> entries;

  const Vault({
    required this.vaultId,
    required this.schemaVersion,
    this.folders = const [],
    this.entries = const [],
  });

  Vault copyWith({List<VaultFolder>? folders, List<VaultEntry>? entries}) {
    return Vault(
      vaultId: vaultId,
      schemaVersion: schemaVersion,
      folders: folders ?? this.folders,
      entries: entries ?? this.entries,
    );
  }

  Map<String, dynamic> toJson() => {
    'schema_version': schemaVersion,
    'vault_id': vaultId,
    'folders': folders.map((f) => f.toJson()).toList(),
    'entries': entries.map((e) => e.toJson()).toList(),
  };

  factory Vault.fromJson(Map<String, dynamic> json) {
    return Vault(
      vaultId: json['vault_id'] as String,
      schemaVersion: json['schema_version'] as int,
      folders: (json['folders'] as List? ?? const [])
          .map((f) => VaultFolder.fromJson(f as Map<String, dynamic>))
          .toList(),
      entries: (json['entries'] as List? ?? const [])
          .map((e) => VaultEntry.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  /// Serializa el payload a los bytes UTF-8 que se cifran (ver
  /// docs/adr/0004-formato-boveda-v1.md — payload JSON dentro del blob).
  Uint8List toJsonBytes() =>
      Uint8List.fromList(utf8.encode(jsonEncode(toJson())));

  factory Vault.fromJsonBytes(Uint8List bytes) {
    return Vault.fromJson(
      jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>,
    );
  }
}
