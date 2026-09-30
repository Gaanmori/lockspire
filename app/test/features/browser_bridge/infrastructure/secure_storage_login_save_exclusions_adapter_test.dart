// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Gabriel Ángel Montoya Rico

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lockspire/features/browser_bridge/infrastructure/secure_storage_login_save_exclusions_adapter.dart';

/// "Nunca en este sitio" (ADR 0034), en el almacenamiento seguro simulado.
void main() {
  late Map<String, String> stored;
  const adapter = SecureStorageLoginSaveExclusionsAdapter(
    FlutterSecureStorage(),
  );

  setUp(() {
    stored = {};
    FlutterSecureStorage.setMockInitialValues(stored);
  });

  test('guarda y quita sitios; sin sitios no queda nada guardado', () async {
    expect(await adapter.isExcluded('banco.example'), isFalse);

    await adapter.exclude('banco.example');
    await adapter.exclude('correo.example');
    await adapter.exclude('banco.example');

    expect(await adapter.all(), {'banco.example', 'correo.example'});
    expect(await adapter.isExcluded('banco.example'), isTrue);

    await adapter.include('banco.example');
    await adapter.include('correo.example');
    expect(stored, isEmpty);
  });

  test('una lista dañada vuelve a preguntar en todos los sitios', () async {
    stored['browser.never_save_sites'] = 'no es json';

    expect(await adapter.all(), isEmpty);
  });
}
