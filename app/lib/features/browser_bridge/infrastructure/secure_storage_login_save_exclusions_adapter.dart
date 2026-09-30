// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Gabriel Ángel Montoya Rico

import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../domain/ports/login_save_exclusions_port.dart';

const _key = 'browser.never_save_sites';

/// [LoginSaveExclusionsPort] en el almacenamiento seguro del sistema: la
/// lista de sitios dice por dónde navega la persona, así que no va en texto
/// plano.
class SecureStorageLoginSaveExclusionsAdapter
    implements LoginSaveExclusionsPort {
  final FlutterSecureStorage _storage;

  const SecureStorageLoginSaveExclusionsAdapter(this._storage);

  @override
  Future<Set<String>> all() async {
    final raw = await _storage.read(key: _key);
    if (raw == null) return {};
    try {
      return {for (final site in jsonDecode(raw) as List) site as String};
    } catch (_) {
      return {}; // Dañado: se vuelve a preguntar en todos los sitios.
    }
  }

  @override
  Future<bool> isExcluded(String site) async => (await all()).contains(site);

  @override
  Future<void> exclude(String site) async => _write({...await all(), site});

  @override
  Future<void> include(String site) async =>
      _write((await all())..remove(site));

  Future<void> _write(Set<String> sites) => sites.isEmpty
      ? _storage.delete(key: _key)
      : _storage.write(key: _key, value: jsonEncode(sites.toList()..sort()));
}
