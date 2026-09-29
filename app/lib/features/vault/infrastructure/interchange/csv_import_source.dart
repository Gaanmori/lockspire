// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Gabriel Ángel Montoya Rico

import '../../domain/entities/entry_fields.dart';
import '../../domain/entities/vault_entry.dart';
import '../../domain/ports/vault_import_source.dart';
import 'csv_codec.dart';
import 'entry_mapping.dart';
import 'package:lockspire/shared/domain/app_problem.dart';

/// De dónde parece venir un CSV, por sus encabezados (ADR 0027).
enum CsvSource { bitwarden, chrome, firefox, keepass, generic }

/// Importa un CSV de Bitwarden, Chrome/Edge/Google, Firefox, KeePassXC o
/// cualquiera con columnas reconocibles de usuario y contraseña.
class CsvImportSource implements VaultImportSource {
  /// Lo que se detectó en el último [parse], para mostrarlo.
  CsvSource? detected;

  @override
  Future<List<VaultEntry>> parse(String content) async {
    final rows = parseCsv(content);
    if (rows.isEmpty) throw const AppProblem(AppProblemCode.importCsvEmpty);
    final header = [for (final h in rows.first) h.trim().toLowerCase()];
    final columns = _Columns(header);
    if (columns.password == null) {
      throw const AppProblem(AppProblemCode.importCsvNoPasswordColumn);
    }
    detected = columns.source;

    final merged = <String, _Draft>{};
    for (final row in rows.skip(1)) {
      String cell(int? index) =>
          index == null || index >= row.length ? '' : row[index];
      final draft = _Draft(
        title: cell(columns.title),
        username: cell(columns.username),
        password: cell(columns.password),
        uris: _splitUris(cell(columns.url), columns.source),
        notes: cell(columns.notes),
        totp: cell(columns.totp),
        custom: _bitwardenFields(cell(columns.fields)),
        isNote: cell(columns.type).trim().toLowerCase() == 'note',
      );
      if (draft.isEmpty) continue;
      // Chrome y Firefox exportan una fila por sitio: misma cuenta, varios
      // sitios → una sola entrada.
      final key = [
        draft.title.trim().toLowerCase(),
        draft.username,
        draft.password,
      ].join('\u0000');
      final existing = merged[key];
      if (existing != null && draft.password.isNotEmpty) {
        existing.uris.addAll(
          draft.uris.where((u) => !existing.uris.contains(u)),
        );
      } else {
        merged[existing == null ? key : '$key\u0000${merged.length}'] = draft;
      }
    }
    return [for (final draft in merged.values) draft.toEntry()];
  }

  /// Bitwarden separa varias URIs con coma dentro de la celda.
  static List<String> _splitUris(String cell, CsvSource source) {
    if (cell.trim().isEmpty) return [];
    if (source != CsvSource.bitwarden) return [cell.trim()];
    return [
      for (final part in cell.split(','))
        if (part.trim().isNotEmpty) part.trim(),
    ];
  }

  /// Columna `fields` de Bitwarden: una línea `nombre: valor` por campo.
  static List<CustomField> _bitwardenFields(String cell) => [
    for (final line in cell.split(RegExp(r'\r?\n')))
      if (line.contains(':'))
        CustomField(
          name: line.substring(0, line.indexOf(':')).trim(),
          value: line.substring(line.indexOf(':') + 1).trim(),
        ),
  ];
}

class _Draft {
  final String title;
  final String username;
  final String password;
  final List<String> uris;
  final String notes;
  final String totp;
  final List<CustomField> custom;
  final bool isNote;

  _Draft({
    required this.title,
    required this.username,
    required this.password,
    required this.uris,
    required this.notes,
    required this.totp,
    required this.custom,
    required this.isNote,
  });

  bool get isEmpty =>
      title.isEmpty &&
      username.isEmpty &&
      password.isEmpty &&
      uris.isEmpty &&
      notes.isEmpty;

  /// Una "nota" de Bitwarden que en realidad es una tarjeta o un documento
  /// exportado por Lockspire (sus campos tienen los nombres del
  /// formulario) vuelve a ser tarjeta o documento.
  VaultEntry toEntry() {
    if (isNote) {
      for (final (type, labels) in [
        (VaultEntryType.card, cardFieldLabels),
        (VaultEntryType.document, documentFieldLabels),
      ]) {
        final split = extractLabeled(custom, labels);
        final numberKey = type == VaultEntryType.card
            ? EntryFields.cardNumber
            : EntryFields.docNumber;
        if (split.fixed.containsKey(numberKey)) {
          return VaultEntry.create(
            title: titleOr(title, uris),
            type: type,
            fields: {
              ...split.fixed,
              ...loginFields(uris: uris, notes: notes, custom: split.rest),
            },
          );
        }
      }
    }
    return VaultEntry.create(
      title: titleOr(title, uris),
      fields: loginFields(
        username: username,
        password: password,
        uris: uris,
        notes: notes,
        custom: custom,
        totp: totp,
      ),
    );
  }
}

/// Índices de las columnas conocidas en el encabezado.
class _Columns {
  final CsvSource source;
  final int? title;
  final int? username;
  final int? password;
  final int? url;
  final int? notes;
  final int? totp;
  final int? fields;
  final int? type;

  factory _Columns(List<String> header) {
    int? find(List<String> names) {
      for (final name in names) {
        final i = header.indexOf(name);
        if (i >= 0) return i;
      }
      return null;
    }

    final source = header.contains('login_password')
        ? CsvSource.bitwarden
        : header.contains('httprealm') || header.contains('formactionorigin')
        ? CsvSource.firefox
        : header.contains('group') && header.contains('title')
        ? CsvSource.keepass
        : header.length >= 4 &&
              header.take(4).join(',') == 'name,url,username,password'
        ? CsvSource.chrome
        : CsvSource.generic;

    return _Columns._(
      source: source,
      title: find([
        'name',
        'title',
        'account',
        'item name',
        'nombre',
        'título',
      ]),
      username: find([
        'login_username',
        'username',
        'user name',
        'user',
        'login',
        'email',
        'usuario',
      ]),
      password: find(['login_password', 'password', 'contraseña', 'pass']),
      url: find([
        'login_uri',
        'url',
        'uri',
        'website',
        'web site',
        'origin',
        'sitio',
      ]),
      notes: find(['notes', 'note', 'comments', 'extra', 'notas']),
      totp: find(['login_totp', 'totp', 'otpauth', 'otp']),
      fields: source == CsvSource.bitwarden ? find(['fields']) : null,
      type: source == CsvSource.bitwarden ? find(['type']) : null,
    );
  }

  const _Columns._({
    required this.source,
    required this.title,
    required this.username,
    required this.password,
    required this.url,
    required this.notes,
    required this.totp,
    required this.fields,
    required this.type,
  });
}
