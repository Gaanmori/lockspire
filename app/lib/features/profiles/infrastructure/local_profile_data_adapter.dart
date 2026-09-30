// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Gabriel Ángel Montoya Rico

import 'dart:io';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:lockspire/shared/profile_paths.dart';
import 'package:lockspire/shared/profile_scoped_secure_storage.dart';

import '../domain/ports/profile_data_port.dart';
import '../domain/profile.dart';

/// Borra la carpeta y las claves de un perfil (ADR 0039).
class LocalProfileDataAdapter implements ProfileDataPort {
  /// Sin prefijo de perfil: `deviceSecureStorageProvider`.
  final FlutterSecureStorage _storage;
  final Future<String> Function() _appDataDirectory;

  const LocalProfileDataAdapter(this._storage, this._appDataDirectory);

  @override
  Future<void> erase(String id) async {
    // El principal no tiene prefijo ni carpeta propia: borrarlo así
    // arrasaría con los datos de la app. Nunca se permite.
    if (id == mainProfileId || id.isEmpty) {
      throw ArgumentError.value(id, 'id', 'el principal no se borra');
    }
    final directory = Directory(
      profileDirectory(await _appDataDirectory(), id),
    );
    if (await directory.exists()) await directory.delete(recursive: true);

    final prefix = profileKeysPrefix(id);
    // Una copia de las claves: borrar mientras se recorre el mapa que
    // devuelve readAll puede fallar según la plataforma.
    final keys = [...(await _storage.readAll()).keys];
    for (final key in keys) {
      if (key.startsWith(prefix)) await _storage.delete(key: key);
    }
  }
}
