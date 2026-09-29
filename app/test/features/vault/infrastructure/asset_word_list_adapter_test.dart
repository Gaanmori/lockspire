// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Gabriel Ángel Montoya Rico

import 'package:flutter_test/flutter_test.dart';
import 'package:lockspire/features/vault/infrastructure/asset_word_list_adapter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // La lista pasó de código Dart a un asset (C3). Solo inglés (ADR 0032).
  group('AssetWordListAdapter', () {
    late List<String> words;

    setUpAll(() async {
      words = await AssetWordListAdapter().load();
    });

    test('carga todas las palabras', () {
      expect(words, hasLength(4438));
    });

    test('todas en minúscula ASCII y de una pieza, de 7 letras o menos', () {
      for (final word in words) {
        expect(word, matches(RegExp(r'^[a-z]{1,7}$')), reason: word);
      }
    });

    test('sin palabras repetidas', () {
      expect(words.toSet(), hasLength(words.length));
    });

    test('carga la lista una sola vez', () async {
      final adapter = AssetWordListAdapter();
      expect(identical(await adapter.load(), await adapter.load()), isTrue);
    });
  });
}
