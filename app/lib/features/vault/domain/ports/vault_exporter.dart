// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Lockspire

import '../entities/vault_entry.dart';

/// Formato de exportación **sin cifrar** a otro gestor (ADR 0027). El
/// respaldo cifrado no pasa por aquí: es el archivo de la bóveda tal cual.
abstract class VaultExporter {
  /// Nombre para mostrar, p. ej. "CSV de Bitwarden".
  String get label;

  /// Para qué sirve, en una línea.
  String get description;

  String get fileExtension;
  String get mimeType;

  /// Si el formato no puede llevar tarjetas y documentos (se omiten).
  bool get passwordsOnly;

  /// Contenido del archivo. [entries] ya viene sin las borradas.
  String encode(List<VaultEntry> entries);
}
