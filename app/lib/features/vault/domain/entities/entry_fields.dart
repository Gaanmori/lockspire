// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Gabriel Ángel Montoya Rico

import 'vault_entry.dart';

/// Keys de [VaultEntry.fields] (ADR 0025). Todo sigue siendo un mapa de
/// texto, así el merge y el historial por campo (ADR 0009) cubren también
/// tarjetas, documentos, sitios y apps.
abstract final class EntryFields {
  static const username = 'username';
  static const password = 'password';
  static const notes = 'notes';

  /// Sitio principal; los demás son `url_2`, `url_3`… ([repeatedKey]).
  static const url = 'url';

  /// Paquete Android principal; los demás son `app_2`, `app_3`…
  static const app = 'app';

  static const cardNumber = 'card_number';
  static const cardHolder = 'card_holder';
  static const cardExpiry = 'card_expiry';
  static const cardCvv = 'card_cvv';
  static const cardPin = 'card_pin';

  static const docNumber = 'doc_number';
  static const docName = 'doc_name';
  static const docBirthDate = 'doc_birth_date';
  static const docIssued = 'doc_issued';
  static const docExpiry = 'doc_expiry';

  /// Campo a medida visible: `custom:<nombre>`.
  static const customPrefix = 'custom:';

  /// Campo a medida oculto (PIN, clave extra…): `hidden:<nombre>`.
  static const hiddenPrefix = 'hidden:';

  /// Keys que se muestran ocultas y se copian como secreto.
  static const secretKeys = {password, cardCvv, cardPin};
}

/// Key del valor número [index] (desde 0) de un campo repetible:
/// `url`, `url_2`, `url_3`…
String repeatedKey(String base, int index) =>
    index == 0 ? base : '${base}_${index + 1}';

/// Posición (desde 0) de [key] dentro del campo repetible [base], o `null`
/// si no le pertenece.
int? repeatedIndex(String base, String key) {
  if (key == base) return 0;
  final match = RegExp('^${RegExp.escape(base)}_(\\d+)\$').firstMatch(key);
  if (match == null) return null;
  final n = int.parse(match.group(1)!);
  return n >= 2 ? n - 1 : null;
}

/// Valores no vacíos del campo repetible [base], en orden.
List<String> repeatedValues(Map<String, String> fields, String base) {
  final indexed = <(int, String)>[];
  for (final MapEntry(:key, :value) in fields.entries) {
    final index = repeatedIndex(base, key);
    if (index != null && value.trim().isNotEmpty) {
      indexed.add((index, value.trim()));
    }
  }
  indexed.sort((a, b) => a.$1.compareTo(b.$1));
  return [for (final (_, value) in indexed) value];
}

/// [values] como keys de [base] (sin huecos), para guardar.
Map<String, String> repeatedFields(String base, Iterable<String> values) {
  final clean = values.map((v) => v.trim()).where((v) => v.isNotEmpty);
  return {
    for (final (index, value) in clean.indexed) repeatedKey(base, index): value,
  };
}

/// Campo a medida (ADR 0025): un nombre elegido por el usuario (o que
/// venía de SafeInCloud) y su valor.
class CustomField {
  final String name;
  final String value;
  final bool hidden;

  const CustomField({
    required this.name,
    required this.value,
    this.hidden = false,
  });

  String get key =>
      '${hidden ? EntryFields.hiddenPrefix : EntryFields.customPrefix}$name';

  static CustomField? fromEntry(String key, String value) {
    if (key.startsWith(EntryFields.customPrefix)) {
      return CustomField(
        name: key.substring(EntryFields.customPrefix.length),
        value: value,
      );
    }
    if (key.startsWith(EntryFields.hiddenPrefix)) {
      return CustomField(
        name: key.substring(EntryFields.hiddenPrefix.length),
        value: value,
        hidden: true,
      );
    }
    return null;
  }
}

/// Campos a medida de [fields], en el orden en que se guardaron.
List<CustomField> customFieldsOf(Map<String, String> fields) => [
  for (final MapEntry(:key, :value) in fields.entries)
    ?CustomField.fromEntry(key, value),
];

extension VaultEntryFieldsX on VaultEntry {
  /// Todos los sitios web de la entrada, el principal primero.
  List<String> get urls => repeatedValues(fields, EntryFields.url);

  /// Todos los paquetes Android de la entrada.
  List<String> get apps => repeatedValues(fields, EntryFields.app);

  List<CustomField> get customFields => customFieldsOf(fields);
}
