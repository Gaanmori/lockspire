// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Gabriel Ángel Montoya Rico

import 'package:flutter_test/flutter_test.dart';
import 'package:lockspire/shared/presentation/preferences.dart';

void main() {
  test('guarda la preferencia y espera a que termine', () async {
    var saved = false;

    await saveAppliedPreference(() async => saved = true);

    expect(saved, isTrue);
  });

  test(
    'si guardar falla, sigue sin error: la preferencia ya está aplicada',
    () async {
      await expectLater(
        saveAppliedPreference(
          () async => throw StateError('sin almacenamiento'),
        ),
        completes,
      );
    },
  );
}
