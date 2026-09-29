// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Gabriel Ángel Montoya Rico

import '../entities/vault_entry.dart';

/// Puerto de origen de importación: convierte el contenido de un archivo
/// exportado por otro gestor de contraseñas en una lista de [VaultEntry]
/// candidatas, listas para persistir con el mismo flujo que una entrada
/// creada a mano (ver `VaultSessionController.importEntries`).
///
/// Genérico a propósito aunque esta fase solo tenga un adaptador
/// (SafeInCloud XML) — agregar otro origen más adelante (ej. Bitwarden/
/// 1Password CSV) no debería obligar a rehacer este puerto.
abstract class VaultImportSource {
  /// Parsea [content] — el contenido ya leído en memoria, **nunca** un
  /// path: el llamador es responsable de leer el archivo elegido por el
  /// usuario sin copiarlo a ningún temporal propio de la app (ver
  /// docs/THREAT_MODEL.md, actor #8 — el archivo de origen no está
  /// cifrado).
  Future<List<VaultEntry>> parse(String content);
}
