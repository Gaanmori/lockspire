// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Gabriel Ángel Montoya Rico

import '../entities/vault_entry.dart';

/// Formatos de exportación sin cifrar.
enum ExportFormat { bitwardenCsv, bitwardenJson, chromeCsv }

/// Formato de exportación **sin cifrar** a otro gestor (ADR 0027). El
/// respaldo cifrado no pasa por aquí: es el archivo de la bóveda tal cual.
abstract class VaultExporter {
  /// Qué formato es. Nombre y descripción los pone la presentación en el
  /// idioma de la app (ADR 0032).
  ExportFormat get format;

  String get fileExtension;
  String get mimeType;

  /// Si el formato no puede llevar tarjetas y documentos (se omiten).
  bool get passwordsOnly;

  /// Contenido del archivo. [entries] ya viene sin las borradas.
  String encode(List<VaultEntry> entries);
}
