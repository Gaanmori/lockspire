// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Gabriel Ángel Montoya Rico

/// Fuente de la lista de palabras del generador "fácil de recordar"
/// (hallazgo C3). Siempre en inglés, sea cual sea el idioma de la app (ADR
/// 0032). No es un secreto (principio de Kerckhoffs): la seguridad está en
/// que `Random.secure()` elige qué palabras, no en que la lista sea
/// desconocida. Procedencia y licencia en `assets/wordlists/README.md`.
abstract class WordListPort {
  Future<List<String>> load();
}
