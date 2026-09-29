// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Gabriel Ángel Montoya Rico

import 'package:flutter_test/flutter_test.dart';
import 'package:lockspire/features/vault/domain/ports/word_list_port.dart';
import 'package:lockspire/features/vault/infrastructure/asset_word_list_adapter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Las listas pasaron de código Dart a assets (C3): mismas reglas que antes.
  group('AssetWordListAdapter', () {
    for (final (language, expectedCount) in [
      (WordListLanguage.spanish, 3050),
      (WordListLanguage.english, 4438),
    ]) {
      group(language.name, () {
        late List<String> words;

        setUpAll(() async {
          words = await AssetWordListAdapter().load(language);
        });

        test('carga todas las palabras', () {
          expect(words, hasLength(expectedCount));
        });

        test('todas en minúscula y de una pieza (ñ permitida, sin acentos, '
            'espacios ni guiones), de 7 letras o menos', () {
          for (final word in words) {
            expect(word, matches(RegExp(r'^[a-zñ]{1,7}$')), reason: word);
          }
        });

        test('sin palabras repetidas', () {
          expect(words.toSet(), hasLength(words.length));
        });
      });
    }

    test('carga cada lista una sola vez', () async {
      final adapter = AssetWordListAdapter();
      expect(
        identical(
          await adapter.load(WordListLanguage.spanish),
          await adapter.load(WordListLanguage.spanish),
        ),
        isTrue,
      );
    });
  });
}
