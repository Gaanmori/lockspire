// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Gabriel Ángel Montoya Rico

import 'dart:convert';

import 'package:xml/xml.dart';

import '../domain/entities/entry_fields.dart';
import '../domain/entities/vault_entry.dart';
import '../domain/ports/vault_import_source.dart';
import 'interchange/entry_mapping.dart' show normalizeFieldName;

/// Prefijo de las líneas que imports anteriores a ADR 0025 dejaban en
/// `notes` para los campos sin mapeo. Ya no se generan; se conserva para
/// detectar y reprocesar esas entradas con [transitionalLineRegExp].
const transitionalPrefix = 'safeincloud-import';

/// Formato de esas líneas: `[safeincloud-import type="…" name="…"] valor`.
final transitionalLineRegExp = RegExp(
  r'^\[' + transitionalPrefix + r' type="([^"]*)" name="([^"]*)"\] (.*)$',
);

/// Implementa [VaultImportSource] para el export XML de SafeInCloud. Mapeo
/// completo en docs/adr/0025-tarjetas-documentos-y-campos-a-medida.md;
/// estructura del export documentada en docs/STATE.md.
class SafeInCloudXmlImportSource implements VaultImportSource {
  @override
  Future<List<VaultEntry>> parse(String content) async {
    final document = XmlDocument.parse(content);
    return [
      for (final card in document.findAllElements('card'))
        if (!_isTruthy(card, 'deleted') && !_isTruthy(card, 'template'))
          _CardImport(card).build(),
    ];
  }

  static bool _isTruthy(XmlElement element, String name) {
    final value = element.getAttribute(name)?.toLowerCase();
    return value == '1' || value == 'true';
  }
}

/// Una `<card>` convertida a entrada.
class _CardImport {
  final XmlElement card;
  final fields = <String, String>{};
  final history = <String, List<FieldHistoryRecord>>{};
  final _urls = <String>[];
  final _apps = <String>[];
  final _notes = <String>[];

  _CardImport(this.card);

  late final List<XmlElement> _fields = card.findElements('field').toList();

  late final VaultEntryType type = () {
    if (_fields.any(
      (f) => (f.getAttribute('autofill') ?? '').startsWith('cc-'),
    )) {
      return VaultEntryType.card;
    }
    const documentSymbols = {'id', 'passport', 'social_security'};
    if (documentSymbols.contains(card.getAttribute('symbol'))) {
      return VaultEntryType.document;
    }
    final types = {
      for (final f in _fields)
        if (f.innerText.trim().isNotEmpty) f.getAttribute('type'),
    };
    final hasCredential = types.any(
      (t) => t == 'login' || t == 'password' || t == 'website',
    );
    if (!hasCredential &&
        (types.contains('date') || types.contains('expiry'))) {
      return VaultEntryType.document;
    }
    return VaultEntryType.password;
  }();

  VaultEntry build() {
    for (final field in _fields) {
      final value = field.innerText;
      if (value.trim().isEmpty) continue;
      final key = _keyFor(field, value);
      if (key == null) continue;
      fields[key] = value;
      final previous = _history(field, value);
      if (previous.isNotEmpty) history[key] = previous;
    }
    for (final note in card.findElements('notes')) {
      final value = note.innerText.trim();
      if (value.isNotEmpty) _notes.add(value);
    }

    fields
      ..addAll(repeatedFields(EntryFields.url, _urls))
      ..addAll(repeatedFields(EntryFields.app, _apps));
    if (_notes.isNotEmpty) fields[EntryFields.notes] = _notes.join('\n\n');

    final title = card.getAttribute('title')?.trim() ?? '';
    return VaultEntry.create(
      title: title.isEmpty ? 'Sin título' : title,
      type: type,
      fields: fields,
      fieldHistory: history,
    );
  }

  /// Key donde va [field], o `null` si ya quedó en una lista (sitios,
  /// apps, notas) que se guarda al final.
  String? _keyFor(XmlElement field, String value) {
    final fieldType = field.getAttribute('type') ?? '';
    final name = (field.getAttribute('name') ?? '').trim();
    final autofill = field.getAttribute('autofill') ?? '';

    final specific = switch (type) {
      VaultEntryType.card => _cardKey(fieldType, name, autofill),
      VaultEntryType.document => _documentKey(fieldType, name),
      _ => null,
    };
    if (specific != null && !fields.containsKey(specific)) return specific;

    switch (fieldType) {
      // Usuario y contraseña propios solo en las contraseñas; en una
      // tarjeta o documento quedan como campos con su nombre.
      case 'login'
          when type == VaultEntryType.password &&
              !fields.containsKey(EntryFields.username):
        return EntryFields.username;
      case 'password'
          when type == VaultEntryType.password &&
              !fields.containsKey(EntryFields.password):
        return EntryFields.password;
      case 'website':
        _urls.add(value.trim());
        return null;
      case 'application':
        _apps.add(value.trim());
        return null;
      case 'text' when _isNotesName(name):
        _notes.add(value.trim());
        return null;
      case 'password' || 'pin' || 'one_time_password':
        return _uniqueCustomKey(EntryFields.hiddenPrefix, name, fieldType);
      default:
        return _uniqueCustomKey(EntryFields.customPrefix, name, fieldType);
    }
  }

  static String? _cardKey(String fieldType, String name, String autofill) {
    switch (autofill) {
      case 'cc-number':
        return EntryFields.cardNumber;
      case 'cc-name':
        return EntryFields.cardHolder;
      case 'cc-exp':
        return EntryFields.cardExpiry;
      case 'cc-csc':
        return EntryFields.cardCvv;
    }
    final n = normalizeFieldName(name);
    if (fieldType == 'pin' && n == 'pin') return EntryFields.cardPin;
    if (fieldType == 'expiry') return EntryFields.cardExpiry;
    if (n == 'titular' || n == 'holder') return EntryFields.cardHolder;
    if (fieldType == 'number' && (n == 'numero' || n == 'number')) {
      return EntryFields.cardNumber;
    }
    return null;
  }

  static String? _documentKey(String fieldType, String name) {
    final n = normalizeFieldName(name);
    if (n.contains('nacimiento') || n.contains('birth')) {
      return EntryFields.docBirthDate;
    }
    if (n.startsWith('expedi') || n.contains('issued')) {
      return EntryFields.docIssued;
    }
    if (fieldType == 'expiry' || n.startsWith('venc') || n == 'vence') {
      return EntryFields.docExpiry;
    }
    if (n == 'numero' || n == 'number' || n == 'no') {
      return EntryFields.docNumber;
    }
    if (n == 'nombre' || n == 'name' || n == 'titular') {
      return EntryFields.docName;
    }
    return null;
  }

  static bool _isNotesName(String name) => const {
    'nota',
    'notas',
    'notes',
    'note',
  }.contains(normalizeFieldName(name));

  String _uniqueCustomKey(String prefix, String name, String fieldType) {
    final base = name.isEmpty ? _typeLabel(fieldType) : name;
    var candidate = base;
    var n = 2;
    bool taken(String c) =>
        fields.containsKey('${EntryFields.customPrefix}$c') ||
        fields.containsKey('${EntryFields.hiddenPrefix}$c');
    while (taken(candidate)) {
      candidate = '$base ($n)';
      n++;
    }
    return '$prefix$candidate';
  }

  static String _typeLabel(String fieldType) => switch (fieldType) {
    'login' => 'Usuario',
    'password' => 'Contraseña',
    'pin' => 'PIN',
    'one_time_password' => 'Secreto 2FA',
    'number' => 'Número',
    'date' => 'Fecha',
    'expiry' => 'Vencimiento',
    'phone' => 'Teléfono',
    _ => 'Campo',
  };

  /// Valores anteriores del campo (atributo `history`, JSON `{ms: valor}`),
  /// del más reciente al más viejo, como los guarda el merge (ADR 0009).
  static List<FieldHistoryRecord> _history(XmlElement field, String current) {
    final raw = field.getAttribute('history');
    if (raw == null || raw.isEmpty) return const [];
    final Object? decoded;
    try {
      decoded = jsonDecode(raw);
    } on FormatException {
      return const [];
    }
    if (decoded is! Map) return const [];
    final records = <FieldHistoryRecord>[];
    final seen = <String>{current};
    for (final MapEntry(:key, :value) in decoded.entries) {
      final ms = int.tryParse('$key');
      if (ms == null || value is! String || value.isEmpty) continue;
      if (!seen.add(value)) continue;
      records.add(
        FieldHistoryRecord(
          value: value,
          replacedAt: DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true),
        ),
      );
    }
    records.sort((a, b) => b.replacedAt.compareTo(a.replacedAt));
    return records.take(maxFieldHistoryPerField).toList();
  }
}
