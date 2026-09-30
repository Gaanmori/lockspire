// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Gabriel Ángel Montoya Rico

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Id del perfil que ya existía antes de los perfiles (ADR 0039). Igual a
/// `mainProfileId` de la feature `profiles`; está aquí para que `shared` no
/// dependa de una feature.
const mainProfileKeyId = 'principal';

/// Prefijo de las claves del dispositivo (la lista de perfiles): no son de
/// ningún perfil.
const deviceKeyPrefix = 'device.';

/// Prefijo de las claves de los perfiles que no son el principal.
const profileKeyPrefix = 'profile.';

/// Prefijo de las claves del perfil [profileId]; vacío en el principal, que
/// conserva las claves de siempre.
String profileKeysPrefix(String profileId) =>
    profileId == mainProfileKeyId ? '' : '$profileKeyPrefix$profileId.';

/// El almacenamiento seguro visto desde un perfil (ADR 0039): cada clave
/// lleva el prefijo del perfil, así dos perfiles nunca leen ni pisan los
/// ajustes del otro (cuentas de nube, clave biométrica, tema…). Los
/// adaptadores no saben de perfiles: reciben esto como su
/// `FlutterSecureStorage`.
class ProfileScopedSecureStorage extends FlutterSecureStorage {
  final String profileId;

  const ProfileScopedSecureStorage(this.profileId);

  String get _prefix => profileKeysPrefix(profileId);

  String _scoped(String key) => '$_prefix$key';

  /// Si una clave guardada es de este perfil. En el principal, las que no
  /// llevan el prefijo de otro perfil ni el del dispositivo.
  bool _isOwn(String storedKey) => _prefix.isEmpty
      ? !storedKey.startsWith(profileKeyPrefix) &&
            !storedKey.startsWith(deviceKeyPrefix)
      : storedKey.startsWith(_prefix);

  @override
  Future<void> write({
    required String key,
    required String? value,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) => super.write(
    key: _scoped(key),
    value: value,
    iOptions: iOptions,
    aOptions: aOptions,
    lOptions: lOptions,
    webOptions: webOptions,
    mOptions: mOptions,
    wOptions: wOptions,
  );

  @override
  Future<String?> read({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) => super.read(
    key: _scoped(key),
    iOptions: iOptions,
    aOptions: aOptions,
    lOptions: lOptions,
    webOptions: webOptions,
    mOptions: mOptions,
    wOptions: wOptions,
  );

  @override
  Future<bool> containsKey({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) => super.containsKey(
    key: _scoped(key),
    iOptions: iOptions,
    aOptions: aOptions,
    lOptions: lOptions,
    webOptions: webOptions,
    mOptions: mOptions,
    wOptions: wOptions,
  );

  @override
  Future<void> delete({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) => super.delete(
    key: _scoped(key),
    iOptions: iOptions,
    aOptions: aOptions,
    lOptions: lOptions,
    webOptions: webOptions,
    mOptions: mOptions,
    wOptions: wOptions,
  );

  /// Solo las claves de este perfil, sin su prefijo.
  @override
  Future<Map<String, String>> readAll({
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    final all = await super.readAll(
      iOptions: iOptions,
      aOptions: aOptions,
      lOptions: lOptions,
      webOptions: webOptions,
      mOptions: mOptions,
      wOptions: wOptions,
    );
    return {
      for (final entry in all.entries)
        if (_isOwn(entry.key)) entry.key.substring(_prefix.length): entry.value,
    };
  }

  /// Borra solo las claves de este perfil: nunca las de otro ni la lista
  /// de perfiles.
  @override
  Future<void> deleteAll({
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    final own = await readAll(
      iOptions: iOptions,
      aOptions: aOptions,
      lOptions: lOptions,
      webOptions: webOptions,
      mOptions: mOptions,
      wOptions: wOptions,
    );
    for (final key in own.keys) {
      await delete(
        key: key,
        iOptions: iOptions,
        aOptions: aOptions,
        lOptions: lOptions,
        webOptions: webOptions,
        mOptions: mOptions,
        wOptions: wOptions,
      );
    }
  }
}
