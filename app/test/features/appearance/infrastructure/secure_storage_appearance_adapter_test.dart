// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Gabriel Ángel Montoya Rico

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lockspire/features/appearance/domain/appearance_preference.dart';
import 'package:lockspire/features/appearance/infrastructure/secure_storage_appearance_adapter.dart';

/// Tema, modo, idioma y color personalizado en el almacenamiento seguro
/// simulado.
void main() {
  late Map<String, String> stored;
  const adapter = SecureStorageAppearanceAdapter(FlutterSecureStorage());

  setUp(() {
    stored = {};
    FlutterSecureStorage.setMockInitialValues(stored);
  });

  test('sin nada guardado: Grafito (ADR 0036)', () async {
    expect(await adapter.load(), AppearancePreference.defaults);
    expect(AppearancePreference.defaults.family, ThemeFamilyId.grafito);
  });

  test('guarda y recupera todo, también el color personalizado', () async {
    const preference = AppearancePreference(
      family: ThemeFamilyId.personalizado,
      mode: AppearanceMode.dark,
      language: AppLanguage.en,
      customColorArgb: 0xFFD32F2F,
    );

    await adapter.save(preference);

    expect(await adapter.load(), preference);
  });

  test('valores dañados o de otra versión vuelven a los por defecto', () async {
    stored['appearance.family'] = 'lavanda';
    stored['appearance.custom_color'] = 'no-es-un-color';

    final preference = await adapter.load();

    expect(preference.family, ThemeFamilyId.grafito);
    expect(
      preference.customColorArgb,
      AppearancePreference.defaultCustomColorArgb,
    );
  });

  test('un color guardado con transparencia se lee opaco', () async {
    stored['appearance.custom_color'] = '80d32f2f';

    expect((await adapter.load()).customColorArgb, 0xFFD32F2F);
  });
}
