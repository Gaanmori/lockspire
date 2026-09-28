// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Lockspire

/// CSV (RFC 4180) para importar y exportar (ADR 0027): comillas dobles,
/// `""` como comilla escapada, saltos de línea dentro de un campo entre
/// comillas, `\r\n` o `\n`, y BOM inicial opcional.
List<List<String>> parseCsv(String input) {
  final text = input.startsWith('﻿') ? input.substring(1) : input;
  final rows = <List<String>>[];
  var row = <String>[];
  final field = StringBuffer();
  var inQuotes = false;
  var fieldStarted = false;

  void endField() {
    row.add(field.toString());
    field.clear();
    fieldStarted = false;
  }

  void endRow() {
    endField();
    // Una línea vacía no es una fila.
    if (!(row.length == 1 && row.single.isEmpty)) rows.add(row);
    row = <String>[];
  }

  for (var i = 0; i < text.length; i++) {
    final c = text[i];
    if (inQuotes) {
      if (c == '"') {
        if (i + 1 < text.length && text[i + 1] == '"') {
          field.write('"');
          i++;
        } else {
          inQuotes = false;
        }
      } else {
        field.write(c);
      }
      continue;
    }
    switch (c) {
      case '"' when !fieldStarted && field.isEmpty:
        inQuotes = true;
        fieldStarted = true;
      case ',':
        endField();
      case '\r':
        if (i + 1 < text.length && text[i + 1] == '\n') i++;
        endRow();
      case '\n':
        endRow();
      default:
        field.write(c);
        fieldStarted = true;
    }
  }
  if (inQuotes) {
    throw const FormatException('El CSV tiene comillas sin cerrar.');
  }
  if (field.isNotEmpty || row.isNotEmpty) endRow();
  return rows;
}

/// Filas a texto CSV, siempre con `\r\n` y comillas donde hacen falta.
String encodeCsv(List<List<String>> rows) {
  String quote(String value) {
    final needsQuotes =
        value.contains(',') ||
        value.contains('"') ||
        value.contains('\n') ||
        value.contains('\r') ||
        value.startsWith(' ') ||
        value.endsWith(' ');
    return needsQuotes ? '"${value.replaceAll('"', '""')}"' : value;
  }

  final lines = rows.map((row) => row.map(quote).join(',')).join('\r\n');
  return '$lines\r\n';
}
