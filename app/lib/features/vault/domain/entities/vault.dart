// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Gabriel Ángel Montoya Rico

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

  /// En qué nube se sincroniza esta bóveda (ADR 0023): un identificador que
  /// interpreta `sync` (`webdav`, `googleDrive`, `oneDrive`). Viaja cifrado
  /// con la bóveda, así todos los dispositivos lo conocen. `null` en bóvedas
  /// que todavía no se sincronizaron (o anteriores a ese ADR).
  final String? syncHome;

  /// Íconos de los sitios guardados (ADR 0029): host → PNG de 48 px en
  /// base64, o `''` si ese sitio no tiene ícono (para no volver a buscarlo).
  /// Uno por sitio aunque varias entradas lo usen. Cifrado con la bóveda y
  /// sincronizado: cada sitio se consulta una sola vez en total.
  final Map<String, String> siteIcons;

  const Vault({
    required this.vaultId,
    required this.schemaVersion,
    this.folders = const [],
    this.entries = const [],
    this.syncHome,
    this.siteIcons = const {},
  });

  Vault copyWith({
    List<VaultFolder>? folders,
    List<VaultEntry>? entries,
    String? syncHome,
    Map<String, String>? siteIcons,
  }) {
    return Vault(
      vaultId: vaultId,
      schemaVersion: schemaVersion,
      folders: folders ?? this.folders,
      entries: entries ?? this.entries,
      syncHome: syncHome ?? this.syncHome,
      siteIcons: siteIcons ?? this.siteIcons,
    );
  }

  /// Agrega o reemplaza íconos de sitios (ADR 0029).
  Vault withSiteIcons(Map<String, String> icons) =>
      copyWith(siteIcons: {...siteIcons, ...icons});

  /// Olvida los sitios sin ícono (`''` y `'-'`), para volver a buscarlos.
  Vault withoutMissingSiteIcons() => copyWith(
    siteIcons: {
      for (final MapEntry(:key, :value) in siteIcons.entries)
        if (value.length > 1) key: value,
    },
  );

  /// Operaciones sobre las entradas (revisión 2026-09-25, hallazgo A2):
  /// la regla de negocio vive en el dominio, no en el controller. Son puras
  /// y reciben la hora ([now], en UTC) para poder testearlas sin reloj
  /// real. Un [id] inexistente deja la bóveda igual.

  Vault withEntryAdded(VaultEntry entry) => withEntriesAdded([entry]);

  /// Varias de una vez, p. ej. el resultado de una importación.
  Vault withEntriesAdded(Iterable<VaultEntry> added) =>
      copyWith(entries: [...entries, ...added]);

  Vault withEntryUpdated({
    required String id,
    required String title,
    required Map<String, String> fields,
    required DateTime now,
  }) => _mapEntry(
    id,
    (e) => e.copyWith(title: title, fields: fields, modifiedAt: now),
  );

  /// Borrado suave (tombstone): la entrada queda en la lista marcada como
  /// borrada, para que el merge (ADR 0006) propague el borrado a los demás
  /// dispositivos en vez de resucitarla.
  Vault withEntryDeleted(String id, {required DateTime now}) => _mapEntry(
    id,
    (e) => e.copyWith(deleted: true, deletedAt: now, modifiedAt: now),
  );

  /// Varias a la vez, en un solo guardado (selección múltiple).
  Vault withEntriesDeleted(Set<String> ids, {required DateTime now}) =>
      copyWith(
        entries: [
          for (final e in entries)
            ids.contains(e.id) && !e.deleted
                ? e.copyWith(deleted: true, deletedAt: now, modifiedAt: now)
                : e,
        ],
      );

  Vault _mapEntry(String id, VaultEntry Function(VaultEntry) change) =>
      copyWith(entries: [for (final e in entries) e.id == id ? change(e) : e]);

  Map<String, dynamic> toJson() => {
    'schema_version': schemaVersion,
    'vault_id': vaultId,
    'folders': folders.map((f) => f.toJson()).toList(),
    'entries': entries.map((e) => e.toJson()).toList(),
    'sync_home': ?syncHome,
    if (siteIcons.isNotEmpty) 'site_icons': siteIcons,
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
      syncHome: json['sync_home'] as String?,
      siteIcons: Map<String, String>.from(
        json['site_icons'] as Map? ?? const {},
      ),
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
