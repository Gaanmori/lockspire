// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Lockspire

import '../../domain/entities/entry_fields.dart';
import '../../domain/entities/vault_entry.dart';
import '../../domain/ports/vault_exporter.dart';
import 'csv_codec.dart';
import 'entry_mapping.dart';

/// CSV de Bitwarden (ADR 0027). Contraseñas como `login`; tarjetas y
/// documentos como `note`, con sus datos en `fields` (`nombre: valor`).
class BitwardenCsvExporter implements VaultExporter {
  @override
  String get label => 'CSV de Bitwarden';

  @override
  String get description =>
      'Sin cifrar. Lo aceptan Bitwarden, Proton Pass, 1Password, KeePassXC '
      'y otros. Tarjetas y documentos van como notas.';

  @override
  String get fileExtension => 'csv';

  @override
  String get mimeType => 'text/csv';

  @override
  bool get passwordsOnly => false;

  static const header = [
    'folder',
    'favorite',
    'type',
    'name',
    'notes',
    'fields',
    'reprompt',
    'login_uri',
    'login_username',
    'login_password',
    'login_totp',
  ];

  @override
  String encode(List<VaultEntry> entries) {
    String f(VaultEntry e, String key) => e.fields[key] ?? '';
    return encodeCsv([
      header,
      for (final e in entries)
        if (e.type == VaultEntryType.password)
          [
            '',
            '',
            'login',
            e.title,
            f(e, EntryFields.notes),
            _fields(e.customFields),
            '0',
            urisOf(e).join(','),
            f(e, EntryFields.username),
            f(e, EntryFields.password),
            '',
          ]
        else
          [
            '',
            '',
            'note',
            e.title,
            f(e, EntryFields.notes),
            _fields(labeledFieldsOf(e)),
            '0',
            urisOf(e).join(','),
            '',
            '',
            '',
          ],
    ]);
  }

  static String _fields(List<CustomField> fields) =>
      fields.map((c) => '${c.name}: ${c.value}').join('\n');
}

/// CSV de Chrome (`name,url,username,password,note`), que también leen
/// Edge, Firefox y Google Password Manager. Solo contraseñas, una fila por
/// sitio para que cada sitio funcione en el navegador.
class ChromeCsvExporter implements VaultExporter {
  @override
  String get label => 'CSV de Chrome';

  @override
  String get description =>
      'Sin cifrar. El formato más simple: lo importan Chrome, Edge, Firefox '
      'y Google Password Manager. Solo contraseñas.';

  @override
  String get fileExtension => 'csv';

  @override
  String get mimeType => 'text/csv';

  @override
  bool get passwordsOnly => true;

  @override
  String encode(List<VaultEntry> entries) {
    String f(VaultEntry e, String key) => e.fields[key] ?? '';
    return encodeCsv([
      const ['name', 'url', 'username', 'password', 'note'],
      for (final e in entries)
        if (e.type == VaultEntryType.password)
          for (final url in e.urls.isEmpty ? const [''] : e.urls)
            [
              e.title,
              url,
              f(e, EntryFields.username),
              f(e, EntryFields.password),
              f(e, EntryFields.notes),
            ],
    ]);
  }
}
