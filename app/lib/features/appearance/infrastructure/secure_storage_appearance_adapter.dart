// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Gabriel Ángel Montoya Rico

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../domain/appearance_preference.dart';
import '../domain/ports/appearance_preferences_port.dart';

const _familyKey = 'appearance.family';
const _modeKey = 'appearance.mode';
const _languageKey = 'appearance.language';
const _customColorKey = 'appearance.custom_color';

/// [AppearancePreferencesPort] sobre `flutter_secure_storage` — el mismo
/// almacenamiento que el resto de preferencias de la app, para no añadir
/// otra dependencia solo por esto.
class SecureStorageAppearanceAdapter implements AppearancePreferencesPort {
  final FlutterSecureStorage _storage;

  const SecureStorageAppearanceAdapter(this._storage);

  @override
  Future<AppearancePreference> load() async {
    try {
      final storedFamily = await _storage.read(key: _familyKey);
      final storedMode = await _storage.read(key: _modeKey);
      final storedLanguage = await _storage.read(key: _languageKey);
      final storedCustom = int.tryParse(
        await _storage.read(key: _customColorKey) ?? '',
        radix: 16,
      );
      final family = ThemeFamilyId.values
          .where((f) => f.name == storedFamily)
          .firstOrNull;
      final mode = AppearanceMode.values
          .where((m) => m.name == storedMode)
          .firstOrNull;
      return AppearancePreference(
        family: family ?? AppearancePreference.defaults.family,
        mode: mode ?? AppearancePreference.defaults.mode,
        language:
            AppLanguage.values
                .where((l) => l.name == storedLanguage)
                .firstOrNull ??
            AppLanguage.system,
        // Opaco siempre: un valor dañado con transparencia no sirve de tema.
        customColorArgb: storedCustom == null
            ? AppearancePreference.defaultCustomColorArgb
            : 0xFF000000 | (storedCustom & 0xFFFFFF),
      );
    } catch (_) {
      // Keyring no disponible (p. ej. Linux sin sesión de keyring) o tests
      // sin plugin: el tema por defecto siempre sirve.
      return AppearancePreference.defaults;
    }
  }

  @override
  Future<void> save(AppearancePreference preference) async {
    await _storage.write(key: _familyKey, value: preference.family.name);
    await _storage.write(key: _modeKey, value: preference.mode.name);
    await _storage.write(key: _languageKey, value: preference.language.name);
    await _storage.write(
      key: _customColorKey,
      value: preference.customColorArgb.toRadixString(16),
    );
  }
}
