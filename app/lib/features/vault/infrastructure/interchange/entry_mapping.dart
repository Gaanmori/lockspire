// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Lockspire

import '../../domain/entities/entry_fields.dart';
import '../../domain/entities/vault_entry.dart';

/// Prefijo de Bitwarden (y otros) para una app Android en la lista de URIs.
const androidAppScheme = 'androidapp://';

/// Nombre con el que viaja un secreto 2FA importado (ADR 0027): no se
/// generan códigos, solo se conserva el secreto.
const totpFieldName = 'TOTP';

/// Nombres para mostrar de los campos fijos de tarjeta y documento; son
/// los mismos del formulario, así el ida y vuelta por formatos que solo
/// tienen "campos con nombre" es exacto.
const cardFieldLabels = {
  EntryFields.cardNumber: 'Número de tarjeta',
  EntryFields.cardHolder: 'Titular',
  EntryFields.cardExpiry: 'Vence',
  EntryFields.cardCvv: 'CVV',
  EntryFields.cardPin: 'PIN',
};

const documentFieldLabels = {
  EntryFields.docNumber: 'Número',
  EntryFields.docName: 'Nombre',
  EntryFields.docBirthDate: 'Fecha de nacimiento',
  EntryFields.docIssued: 'Expedido',
  EntryFields.docExpiry: 'Vence',
};

/// Todos los datos con nombre de [entry] que no son usuario, contraseña,
/// sitios, apps ni notas: los fijos de tarjeta o documento y los campos a
/// medida. Para formatos que solo tienen "campos con nombre".
List<CustomField> labeledFieldsOf(VaultEntry entry) {
  final fixed = switch (entry.type) {
    VaultEntryType.card => cardFieldLabels,
    VaultEntryType.document => documentFieldLabels,
    _ => const <String, String>{},
  };
  return [
    for (final MapEntry(:key, value: label) in fixed.entries)
      if ((entry.fields[key] ?? '').isNotEmpty)
        CustomField(
          name: label,
          value: entry.fields[key]!,
          hidden:
              EntryFields.secretKeys.contains(key) ||
              key == EntryFields.cardNumber,
        ),
    ...entry.customFields,
  ];
}

/// Sitios y apps de [entry] como URIs, las apps con [androidAppScheme].
List<String> urisOf(VaultEntry entry) => [
  ...entry.urls,
  for (final app in entry.apps) '$androidAppScheme$app',
];

/// Arma los `fields` de una entrada a partir de lo que traen los formatos
/// de otros gestores: separa apps de sitios y pone cada campo con nombre
/// donde corresponde.
Map<String, String> loginFields({
  String username = '',
  String password = '',
  Iterable<String> uris = const [],
  String notes = '',
  Iterable<CustomField> custom = const [],
  String totp = '',
}) {
  final urls = <String>[];
  final apps = <String>[];
  for (final raw in uris) {
    final uri = raw.trim();
    if (uri.isEmpty) continue;
    if (uri.toLowerCase().startsWith(androidAppScheme)) {
      apps.add(uri.substring(androidAppScheme.length));
    } else {
      urls.add(uri);
    }
  }
  return {
    if (username.isNotEmpty) EntryFields.username: username,
    if (password.isNotEmpty) EntryFields.password: password,
    ...repeatedFields(EntryFields.url, urls),
    ...repeatedFields(EntryFields.app, apps),
    ...customFieldMap([
      ...custom,
      if (totp.isNotEmpty)
        CustomField(name: totpFieldName, value: totp, hidden: true),
    ]),
    if (notes.trim().isNotEmpty) EntryFields.notes: notes.trim(),
  };
}

/// Campos a medida como keys, sin pisar nombres repetidos ("PIN (2)").
Map<String, String> customFieldMap(Iterable<CustomField> fields) {
  final result = <String, String>{};
  final names = <String>{};
  for (final field in fields) {
    if (field.value.isEmpty) continue;
    final base = field.name.trim().isEmpty ? 'Campo' : field.name.trim();
    var name = base;
    for (var n = 2; !names.add(name); n++) {
      name = '$base ($n)';
    }
    result[CustomField(
          name: name,
          value: field.value,
          hidden: field.hidden,
        ).key] =
        field.value;
  }
  return result;
}

/// Del lado inverso: saca de [custom] los campos cuyo nombre corresponde a
/// un campo fijo ([labels]) y los pone en su key. Devuelve los fijos y los
/// que quedan como campos a medida.
({Map<String, String> fixed, List<CustomField> rest}) extractLabeled(
  Iterable<CustomField> custom,
  Map<String, String> labels,
) {
  final byLabel = {
    for (final MapEntry(:key, :value) in labels.entries) _norm(value): key,
  };
  final fixed = <String, String>{};
  final rest = <CustomField>[];
  for (final field in custom) {
    final key = byLabel[_norm(field.name)];
    if (key != null && !fixed.containsKey(key) && field.value.isNotEmpty) {
      fixed[key] = field.value;
    } else {
      rest.add(field);
    }
  }
  return (fixed: fixed, rest: rest);
}

/// `MM/AA` o `MM/AAAA` → mes y año de 4 dígitos; `null` si no tiene esa
/// forma.
({int month, int year})? parseCardExpiry(String value) {
  final match = RegExp(
    r'^\s*(\d{1,2})\s*[/\-]\s*(\d{2}|\d{4})\s*$',
  ).firstMatch(value);
  if (match == null) return null;
  final month = int.parse(match.group(1)!);
  var year = int.parse(match.group(2)!);
  if (month < 1 || month > 12) return null;
  if (year < 100) year += 2000;
  return (month: month, year: year);
}

String formatCardExpiry(int month, int year) =>
    '${month.toString().padLeft(2, '0')}/${(year % 100).toString().padLeft(2, '0')}';

String _norm(String s) {
  const accents = {'á': 'a', 'é': 'e', 'í': 'i', 'ó': 'o', 'ú': 'u'};
  return s.trim().toLowerCase().split('').map((c) => accents[c] ?? c).join();
}

/// Título de respaldo: el host del primer sitio, o "Sin título".
String titleOr(String title, Iterable<String> uris) {
  if (title.trim().isNotEmpty) return title.trim();
  for (final uri in uris) {
    if (uri.startsWith(androidAppScheme)) continue;
    final withScheme = uri.contains('://') ? uri : 'https://$uri';
    final host = Uri.tryParse(withScheme)?.host ?? '';
    if (host.isNotEmpty) return host;
  }
  return 'Sin título';
}
