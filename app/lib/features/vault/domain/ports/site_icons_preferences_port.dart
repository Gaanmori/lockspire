// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Gabriel Ángel Montoya Rico

/// Si el usuario activó los íconos de los sitios (ADR 0029). Apagado por
/// defecto: descargarlos le hace saber a cada sitio que se visitó.
abstract class SiteIconsPreferencesPort {
  Future<bool> load();
  Future<void> save(bool enabled);

  /// Completar con DuckDuckGo los que el sitio no ofrece (ADR 0030).
  /// También apagado por defecto.
  Future<bool> loadFallback();
  Future<void> saveFallback(bool enabled);
}
