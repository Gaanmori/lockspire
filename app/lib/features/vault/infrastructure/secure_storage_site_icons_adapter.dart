// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Gabriel Ángel Montoya Rico

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../domain/ports/site_icons_preferences_port.dart';

const _key = 'vault.site_icons_enabled';
const _fallbackKey = 'vault.site_icons_duckduckgo';

/// [SiteIconsPreferencesPort] en el almacenamiento seguro del sistema.
class SecureStorageSiteIconsAdapter implements SiteIconsPreferencesPort {
  final FlutterSecureStorage _storage;

  const SecureStorageSiteIconsAdapter(this._storage);

  @override
  Future<bool> load() async => await _storage.read(key: _key) == 'true';

  @override
  Future<void> save(bool enabled) => enabled
      ? _storage.write(key: _key, value: 'true')
      : _storage.delete(key: _key);

  @override
  Future<bool> loadFallback() async =>
      await _storage.read(key: _fallbackKey) == 'true';

  @override
  Future<void> saveFallback(bool enabled) => enabled
      ? _storage.write(key: _fallbackKey, value: 'true')
      : _storage.delete(key: _fallbackKey);
}
