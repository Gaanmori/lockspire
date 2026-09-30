// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Gabriel Ángel Montoya Rico

import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:lockspire/shared/profile_scoped_secure_storage.dart';

import '../domain/ports/profile_registry_port.dart';
import '../domain/profile_registry.dart';

/// La lista de perfiles en el almacenamiento seguro del dispositivo, fuera
/// de todo perfil (ADR 0039).
class SecureStorageProfileRegistryAdapter implements ProfileRegistryPort {
  static const key = '${deviceKeyPrefix}profiles';

  /// Sin prefijo de perfil: `deviceSecureStorageProvider`.
  final FlutterSecureStorage _storage;

  const SecureStorageProfileRegistryAdapter(this._storage);

  @override
  Future<ProfileRegistry> load({required String mainName}) async {
    final raw = await _storage.read(key: key);
    if (raw == null) return ProfileRegistry.initial(mainName: mainName);
    try {
      final json = jsonDecode(raw);
      if (json is Map) {
        return ProfileRegistry.fromJson(
          json.cast<String, Object?>(),
          mainName: mainName,
        );
      }
    } on FormatException {
      // Abajo: dato corrupto.
    }
    // Si la lista se corrompe, se vuelve a la instalación de siempre: el
    // perfil principal sigue abriendo su bóveda. Los demás perfiles
    // conservan sus archivos y claves en disco.
    return ProfileRegistry.initial(mainName: mainName);
  }

  @override
  Future<void> save(ProfileRegistry registry) =>
      _storage.write(key: key, value: jsonEncode(registry.toJson()));
}
