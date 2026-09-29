// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Gabriel Ángel Montoya Rico

/// Idioma de la lista de palabras del generador "fácil de recordar".
enum WordListLanguage { spanish, english }

/// Fuente de las listas de palabras del generador (hallazgo C3). No son un
/// secreto (principio de Kerckhoffs): la seguridad está en que
/// `Random.secure()` elige qué palabras, no en que la lista sea
/// desconocida. Procedencia y licencias en `assets/wordlists/README.md`.
abstract class WordListPort {
  Future<List<String>> load(WordListLanguage language);
}
