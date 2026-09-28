// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Lockspire

import 'package:flutter/services.dart';

import '../domain/ports/word_list_port.dart';

/// [WordListPort] sobre `assets/wordlists/*.txt` (una palabra por línea).
/// Cada lista se carga una sola vez.
class AssetWordListAdapter implements WordListPort {
  final AssetBundle _bundle;
  final _cache = <WordListLanguage, Future<List<String>>>{};

  AssetWordListAdapter([AssetBundle? bundle]) : _bundle = bundle ?? rootBundle;

  @override
  Future<List<String>> load(WordListLanguage language) =>
      _cache.putIfAbsent(language, () async {
        final file = switch (language) {
          WordListLanguage.spanish => 'assets/wordlists/es.txt',
          WordListLanguage.english => 'assets/wordlists/en.txt',
        };
        final text = await _bundle.loadString(file);
        return List.unmodifiable(
          text.split('\n').map((w) => w.trim()).where((w) => w.isNotEmpty),
        );
      });
}
