// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Gabriel Ángel Montoya Rico

/// Abre un enlace fuera de la app (navegador del sistema).
abstract class ExternalLinkPort {
  /// `false` si no se pudo abrir.
  Future<bool> open(Uri url);
}
