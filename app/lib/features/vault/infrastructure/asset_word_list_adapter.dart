// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Gabriel Ángel Montoya Rico

import 'package:flutter/services.dart';

import '../domain/ports/word_list_port.dart';

/// [WordListPort] sobre `assets/wordlists/en.txt` (una palabra por línea).
/// Se carga una sola vez.
class AssetWordListAdapter implements WordListPort {
  final AssetBundle _bundle;
  Future<List<String>>? _cache;

  AssetWordListAdapter([AssetBundle? bundle]) : _bundle = bundle ?? rootBundle;

  @override
  Future<List<String>> load() => _cache ??= () async {
    final text = await _bundle.loadString('assets/wordlists/en.txt');
    return List<String>.unmodifiable(
      text.split('\n').map((w) => w.trim()).where((w) => w.isNotEmpty),
    );
  }();
}
