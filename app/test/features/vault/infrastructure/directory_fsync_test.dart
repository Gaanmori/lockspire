// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Gabriel Ángel Montoya Rico

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lockspire/features/vault/infrastructure/directory_fsync.dart';

void main() {
  // En Linux (CI) ejerce el FFI real contra la libc; en Windows es un no-op.
  group('fsyncDirectory (S12)', () {
    test('sincroniza un directorio existente sin lanzar', () async {
      final dir = await Directory.systemTemp.createTemp('lockspire_fsync_');
      addTearDown(() => dir.delete(recursive: true));
      expect(() => fsyncDirectory(dir.path), returnsNormally);
    });

    test('es best-effort: un directorio inexistente no lanza', () {
      expect(
        () => fsyncDirectory('/no/existe/lockspire-${DateTime.now()}'),
        returnsNormally,
      );
    });
  });
}
