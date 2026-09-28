// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Lockspire

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../domain/ports/vault_exporter.dart';
import '../../domain/ports/vault_import_source.dart';
import '../../infrastructure/interchange/bitwarden_json.dart';
import '../../infrastructure/interchange/csv_exporters.dart';
import '../../infrastructure/interchange/csv_import_source.dart';
import '../../infrastructure/safeincloud_xml_import_source.dart';

part 'vault_import_source_provider.g.dart';

/// Composition root de los formatos de importación (ADR 0027): el
/// adaptador según la extensión del archivo elegido, o `null` si no es un
/// formato de texto conocido. El respaldo `.lockspire` va aparte porque
/// necesita contraseña (`ReadEncryptedBackupUseCase`).
@Riverpod(keepAlive: true)
VaultImportSource? vaultImportSource(Ref ref, String extension) =>
    switch (extension.toLowerCase()) {
      'xml' => SafeInCloudXmlImportSource(),
      'csv' => CsvImportSource(),
      'json' => BitwardenJsonImportSource(),
      _ => null,
    };

/// Formatos de exportación sin cifrar (ADR 0027), en el orden en que se
/// ofrecen.
@Riverpod(keepAlive: true)
List<VaultExporter> vaultExporters(Ref ref) => [
  BitwardenCsvExporter(),
  BitwardenJsonExporter(),
  ChromeCsvExporter(),
];
