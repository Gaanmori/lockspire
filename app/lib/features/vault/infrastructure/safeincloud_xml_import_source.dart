// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Lockspire

import 'package:xml/xml.dart';

import '../domain/entities/vault_entry.dart';
import '../domain/ports/vault_import_source.dart';

/// Prefijo de los campos de SafeInCloud que Lockspire todavía no modela
/// como tipo estructurado propio (TOTP, tarjetas) — ver
/// [buildTransitionalNoteLine]/[transitionalLineRegExp] para el formato.
const _transitionalPrefix = 'safeincloud-import';

/// Regex para reprocesar una línea generada por [buildTransitionalNoteLine]
/// — ej. cuando exista una fase futura de `VaultEntryType.totp`/`.card` que
/// necesite migrar estos datos a un tipo estructurado.
final transitionalLineRegExp = RegExp(
  r'^\[' + _transitionalPrefix + r' type="([^"]*)" name="([^"]*)"\] (.*)$',
);

/// Arma la línea de nota para un campo de SafeInCloud sin mapeo
/// estructurado en Lockspire — formato estable y parseable a propósito
/// (ver docs/STATE.md, Fase 6): `name` nunca lleva `"` (se reemplaza por
/// `'`) y el valor nunca lleva saltos de línea (se reemplazan por
/// espacios), para que la línea completa sea siempre parseable con
/// [transitionalLineRegExp].
String buildTransitionalNoteLine({required String type, required String name, required String value}) {
  final safeName = name.replaceAll('"', "'");
  final safeValue = value.replaceAll('\n', ' ').replaceAll('\r', ' ');
  return '[$_transitionalPrefix type="$type" name="$safeName"] $safeValue';
}

/// Implementa [VaultImportSource] para el export XML de SafeInCloud (ver
/// docs/STATE.md — Fase 6, schema confirmado contra un export real).
class SafeInCloudXmlImportSource implements VaultImportSource {
  @override
  Future<List<VaultEntry>> parse(String content) async {
    final document = XmlDocument.parse(content);
    final entries = <VaultEntry>[];

    for (final card in document.findAllElements('card')) {
      if (_isTruthyAttribute(card, 'deleted') ||
          _isTruthyAttribute(card, 'template')) {
        continue;
      }

      final title = card.getAttribute('title')?.trim();
      final fields = <String, String>{};
      final notesParagraphs = <String>[];
      final transitionalLines = <String>[];

      for (final field in card.findElements('field')) {
        final type = field.getAttribute('type') ?? '';
        final name = field.getAttribute('name') ?? type;
        final value = field.innerText;
        if (value.isEmpty) continue;

        switch (type) {
          case 'login':
            fields['username'] = value;
          case 'password':
            fields['password'] = value;
          case 'website':
            fields['url'] = value;
          case 'text':
            notesParagraphs.add(value);
          default:
            transitionalLines.add(
              buildTransitionalNoteLine(type: type, name: name, value: value),
            );
        }
      }

      final notes = [
        ...notesParagraphs,
        if (transitionalLines.isNotEmpty) ...transitionalLines,
      ].join('\n');
      if (notes.isNotEmpty) fields['notes'] = notes;

      entries.add(
        VaultEntry.create(
          title: (title == null || title.isEmpty) ? 'Sin título' : title,
          fields: fields,
        ),
      );
    }

    return entries;
  }

  bool _isTruthyAttribute(XmlElement element, String name) {
    final value = element.getAttribute(name);
    return value == '1' || value?.toLowerCase() == 'true';
  }
}
