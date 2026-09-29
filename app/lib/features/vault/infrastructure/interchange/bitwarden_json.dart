// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Gabriel Ángel Montoya Rico

import 'dart:convert';

import '../../domain/entities/entry_fields.dart';
import '../../domain/entities/vault_entry.dart';
import '../../domain/ports/vault_exporter.dart';
import '../../domain/ports/vault_import_source.dart';
import 'entry_mapping.dart';
import 'package:lockspire/shared/domain/app_problem.dart';

// Tipos de ítem y de campo del formato de Bitwarden.
const _login = 1;
const _secureNote = 2;
const _card = 3;
const _identity = 4;
const _fieldText = 0;
const _fieldHidden = 1;

/// JSON **sin cifrar** de Bitwarden (ADR 0027): logins, notas, tarjetas e
/// identidades (documentos).
class BitwardenJsonImportSource implements VaultImportSource {
  @override
  Future<List<VaultEntry>> parse(String content) async {
    final Object? json;
    try {
      json = jsonDecode(content);
    } on FormatException {
      throw const AppProblem(AppProblemCode.importInvalidJson);
    }
    if (json is! Map) {
      throw const AppProblem(AppProblemCode.importNotBitwardenJson);
    }
    if (json['encrypted'] == true) {
      throw const AppProblem(AppProblemCode.importBitwardenEncrypted);
    }
    final items = json['items'];
    if (items is! List) {
      throw const AppProblem(AppProblemCode.importNotBitwardenJson);
    }
    return [
      for (final item in items)
        if (item is Map) ?_entryFrom(item.cast<String, Object?>()),
    ];
  }

  static VaultEntry? _entryFrom(Map<String, Object?> item) {
    String s(Object? v) => v is String ? v : (v == null ? '' : '$v');
    Map<String, Object?> obj(Object? v) =>
        v is Map ? v.cast<String, Object?>() : const {};

    final title = s(item['name']);
    final notes = s(item['notes']);
    final custom = [
      for (final field in (item['fields'] as List? ?? const []))
        if (field is Map && field['type'] != 3)
          CustomField(
            name: s(field['name']),
            value: s(field['value']),
            hidden: field['type'] == _fieldHidden,
          ),
    ];

    switch (item['type']) {
      case _login:
        final login = obj(item['login']);
        final uris = [
          for (final uri in (login['uris'] as List? ?? const []))
            if (uri is Map) s(uri['uri']),
        ];
        final history = <FieldHistoryRecord>[
          for (final h in (item['passwordHistory'] as List? ?? const []))
            if (h is Map &&
                s(h['password']).isNotEmpty &&
                DateTime.tryParse(s(h['lastUsedDate'])) != null)
              FieldHistoryRecord(
                value: s(h['password']),
                replacedAt: DateTime.parse(s(h['lastUsedDate'])).toUtc(),
              ),
        ]..sort((a, b) => b.replacedAt.compareTo(a.replacedAt));
        return VaultEntry.create(
          title: titleOr(title, uris),
          fields: loginFields(
            username: s(login['username']),
            password: s(login['password']),
            uris: uris,
            notes: notes,
            custom: custom,
            totp: s(login['totp']),
          ),
          fieldHistory: {
            if (history.isNotEmpty)
              EntryFields.password: history
                  .take(maxFieldHistoryPerField)
                  .toList(),
          },
        );
      case _card:
        final card = obj(item['card']);
        final split = extractLabeled(custom, cardFieldLabels);
        final month = int.tryParse(s(card['expMonth']));
        final year = int.tryParse(s(card['expYear']));
        return VaultEntry.create(
          title: titleOr(title, const []),
          type: VaultEntryType.card,
          fields: {
            ...split.fixed,
            if (s(card['number']).isNotEmpty)
              EntryFields.cardNumber: s(card['number']),
            if (s(card['cardholderName']).isNotEmpty)
              EntryFields.cardHolder: s(card['cardholderName']),
            if (month != null && year != null)
              EntryFields.cardExpiry: formatCardExpiry(month, year),
            if (s(card['code']).isNotEmpty)
              EntryFields.cardCvv: s(card['code']),
            ...loginFields(
              notes: notes,
              custom: [
                if (s(card['brand']).isNotEmpty)
                  CustomField(name: 'Marca', value: s(card['brand'])),
                ...split.rest,
              ],
            ),
          },
        );
      case _identity:
        final identity = obj(item['identity']);
        final split = extractLabeled(custom, documentFieldLabels);
        final name = [
          s(identity['firstName']),
          s(identity['middleName']),
          s(identity['lastName']),
        ].where((p) => p.isNotEmpty).join(' ');
        final number = [
          s(identity['passportNumber']),
          s(identity['licenseNumber']),
          s(identity['ssn']),
        ].firstWhere((n) => n.isNotEmpty, orElse: () => '');
        final address = [
          s(identity['address1']),
          s(identity['address2']),
          s(identity['address3']),
          s(identity['city']),
          s(identity['state']),
          s(identity['postalCode']),
          s(identity['country']),
        ].where((p) => p.isNotEmpty).join(', ');
        return VaultEntry.create(
          title: titleOr(title, const []),
          type: VaultEntryType.document,
          fields: {
            if (number.isNotEmpty) EntryFields.docNumber: number,
            if (name.isNotEmpty) EntryFields.docName: name,
            ...split.fixed,
            ...loginFields(
              notes: notes,
              custom: [
                for (final (key, label) in const [
                  ('email', 'Email'),
                  ('phone', 'Teléfono'),
                  ('company', 'Empresa'),
                  ('username', 'Usuario'),
                ])
                  if (s(identity[key]).isNotEmpty)
                    CustomField(name: label, value: s(identity[key])),
                if (address.isNotEmpty)
                  CustomField(name: 'Dirección', value: address),
                ...split.rest,
              ],
            ),
          },
        );
      case _secureNote:
        return VaultEntry.create(
          title: titleOr(title, const []),
          fields: loginFields(notes: notes, custom: custom),
        );
      default:
        return null;
    }
  }
}

class BitwardenJsonExporter implements VaultExporter {
  @override
  ExportFormat get format => ExportFormat.bitwardenJson;

  @override
  String get fileExtension => 'json';

  @override
  String get mimeType => 'application/json';

  @override
  bool get passwordsOnly => false;

  @override
  String encode(List<VaultEntry> entries) {
    return const JsonEncoder.withIndent('  ').convert({
      'encrypted': false,
      'folders': <Object>[],
      'items': [for (final e in entries) _item(e)],
    });
  }

  static Map<String, Object?> _item(VaultEntry e) {
    String f(String key) => e.fields[key] ?? '';
    Map<String, Object?> field(CustomField c) => {
      'name': c.name,
      'value': c.value,
      'type': c.hidden ? _fieldHidden : _fieldText,
      'linkedId': null,
    };
    final base = <String, Object?>{
      'id': e.id,
      'organizationId': null,
      'folderId': null,
      'reprompt': 0,
      'name': e.title,
      'notes': f(EntryFields.notes).isEmpty ? null : f(EntryFields.notes),
      'favorite': false,
      'collectionIds': null,
      'creationDate': e.createdAt.toUtc().toIso8601String(),
      'revisionDate': e.modifiedAt.toUtc().toIso8601String(),
    };
    switch (e.type) {
      case VaultEntryType.card:
        final expiry = parseCardExpiry(f(EntryFields.cardExpiry));
        final extras = [
          if (f(EntryFields.cardPin).isNotEmpty)
            CustomField(
              name: cardFieldLabels[EntryFields.cardPin]!,
              value: f(EntryFields.cardPin),
              hidden: true,
            ),
          if (expiry == null && f(EntryFields.cardExpiry).isNotEmpty)
            CustomField(
              name: cardFieldLabels[EntryFields.cardExpiry]!,
              value: f(EntryFields.cardExpiry),
            ),
          ...e.customFields,
        ];
        return {
          ...base,
          'type': _card,
          'card': {
            'cardholderName': _orNull(f(EntryFields.cardHolder)),
            'brand': null,
            'number': _orNull(f(EntryFields.cardNumber)),
            'expMonth': expiry == null ? null : '${expiry.month}',
            'expYear': expiry == null ? null : '${expiry.year}',
            'code': _orNull(f(EntryFields.cardCvv)),
          },
          'fields': [for (final c in extras) field(c)],
        };
      case VaultEntryType.document:
        final extras = [
          for (final key in [
            EntryFields.docNumber,
            EntryFields.docBirthDate,
            EntryFields.docIssued,
            EntryFields.docExpiry,
          ])
            if (f(key).isNotEmpty)
              CustomField(name: documentFieldLabels[key]!, value: f(key)),
          ...e.customFields,
        ];
        return {
          ...base,
          'type': _identity,
          'identity': {'firstName': _orNull(f(EntryFields.docName))},
          'fields': [for (final c in extras) field(c)],
        };
      default:
        return {
          ...base,
          'type': _login,
          'login': {
            'uris': [
              for (final uri in urisOf(e)) {'match': null, 'uri': uri},
            ],
            'username': _orNull(f(EntryFields.username)),
            'password': _orNull(f(EntryFields.password)),
            'totp': null,
          },
          'passwordHistory': [
            for (final h in e.fieldHistory[EntryFields.password] ?? const [])
              {
                'lastUsedDate': h.replacedAt.toUtc().toIso8601String(),
                'password': h.value,
              },
          ],
          'fields': [for (final c in e.customFields) field(c)],
        };
    }
  }

  static String? _orNull(String value) => value.isEmpty ? null : value;
}
