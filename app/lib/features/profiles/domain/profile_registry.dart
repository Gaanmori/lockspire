// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Gabriel Ángel Montoya Rico

import 'package:lockspire/shared/domain/app_problem.dart';
import 'package:lockspire/shared/domain/profile_ids.dart';

import 'profile.dart';

/// Largo máximo del nombre de un perfil: cabe en la lista del desbloqueo.
const maxProfileNameLength = 30;

/// Los perfiles del dispositivo, cuál se usó por última vez y si están
/// activados (ADR 0039). Inmutable: cada cambio devuelve otro registro.
class ProfileRegistry {
  /// Siempre empieza por el perfil principal.
  final List<Profile> profiles;
  final String lastUsedId;

  /// `null`: el usuario nunca lo cambió; vale lo de la plataforma
  /// (activados en escritorio, desactivados en Android).
  final bool? enabled;

  const ProfileRegistry({
    required this.profiles,
    required this.lastUsedId,
    this.enabled,
  });

  /// La instalación de siempre: solo el perfil principal.
  factory ProfileRegistry.initial({required String mainName}) =>
      ProfileRegistry(
        profiles: [Profile(id: mainProfileId, name: mainName)],
        lastUsedId: mainProfileId,
      );

  Profile get main => profiles.first;

  /// El último usado; si ya no existe, el principal.
  Profile get lastUsed => byId(lastUsedId) ?? main;

  Profile? byId(String id) {
    for (final profile in profiles) {
      if (profile.id == id) return profile;
    }
    return null;
  }

  bool isEnabled({required bool defaultEnabled}) => enabled ?? defaultEnabled;

  /// Si la lista se muestra al abrir: activados y con más de uno.
  bool showsPicker({required bool defaultEnabled}) =>
      isEnabled(defaultEnabled: defaultEnabled) && profiles.length > 1;

  /// Agrega un perfil con [id] (lo genera quien llama) y lo deja como el
  /// último usado, para abrirlo enseguida.
  ///
  /// [mainDisplayName]: cómo se ve el principal mientras no tenga nombre
  /// propio ("Principal", en el idioma de la app). Otro perfil no puede
  /// llamarse igual, o la lista tendría dos iguales.
  ProfileRegistry add({
    required String id,
    required String name,
    String mainDisplayName = '',
  }) {
    checkProfileId(id);
    final clean = _validName(name, mainDisplayName: mainDisplayName);
    if (byId(id) != null) throw ArgumentError.value(id, 'id', 'ya existe');
    return _copy(
      profiles: [
        ...profiles,
        Profile(id: id, name: clean),
      ],
      lastUsedId: id,
    );
  }

  /// Ver [add] para [mainDisplayName].
  ProfileRegistry rename(
    String id,
    String name, {
    String mainDisplayName = '',
  }) {
    _require(id);
    final clean = _validName(
      name,
      ignoringId: id,
      mainDisplayName: mainDisplayName,
    );
    return _copy(
      profiles: [for (final p in profiles) p.id == id ? p.renamed(clean) : p],
    );
  }

  /// Quita un perfil que no sea el principal. Si era el último usado, pasa
  /// a serlo el principal.
  ProfileRegistry remove(String id) {
    final profile = _require(id);
    if (profile.isMain) {
      throw const AppProblem(AppProblemCode.profileMainNotRemovable);
    }
    return _copy(
      profiles: [
        for (final p in profiles)
          if (p.id != id) p,
      ],
      lastUsedId: lastUsedId == id ? mainProfileId : lastUsedId,
    );
  }

  ProfileRegistry select(String id) {
    _require(id);
    return _copy(lastUsedId: id);
  }

  /// Se pueden desactivar solo con un perfil: si no, los demás quedarían
  /// inaccesibles sin aviso.
  ProfileRegistry setEnabled(bool value) {
    if (!value && profiles.length > 1) {
      throw const AppProblem(AppProblemCode.profilesInUse);
    }
    return _copy(enabled: value);
  }

  Profile _require(String id) =>
      byId(id) ?? (throw ArgumentError.value(id, 'id', 'no existe'));

  String _validName(
    String name, {
    String? ignoringId,
    required String mainDisplayName,
  }) {
    final clean = name.trim();
    if (clean.isEmpty) {
      throw const AppProblem(AppProblemCode.profileNameEmpty);
    }
    if (clean.length > maxProfileNameLength) {
      throw const AppProblem(AppProblemCode.profileNameTooLong);
    }
    String shown(Profile p) =>
        p.isMain && p.name.isEmpty ? mainDisplayName : p.name;
    final taken = profiles.any(
      (p) =>
          p.id != ignoringId && shown(p).toLowerCase() == clean.toLowerCase(),
    );
    if (taken) throw const AppProblem(AppProblemCode.profileNameTaken);
    return clean;
  }

  ProfileRegistry _copy({
    List<Profile>? profiles,
    String? lastUsedId,
    bool? enabled,
  }) => ProfileRegistry(
    profiles: profiles ?? this.profiles,
    lastUsedId: lastUsedId ?? this.lastUsedId,
    enabled: enabled ?? this.enabled,
  );

  Map<String, Object?> toJson() => {
    'profiles': [for (final p in profiles) p.toJson()],
    'lastUsed': lastUsedId,
    'enabled': ?enabled,
  };

  /// Lee lo guardado. Si falta el principal (dato corrupto), lo repone al
  /// principio: nunca se pierde el acceso a la bóveda de siempre.
  factory ProfileRegistry.fromJson(
    Map<String, Object?> json, {
    required String mainName,
  }) {
    // Un id inválido (dato manipulado) se descarta: iría en una ruta de
    // archivos.
    final list = [
      for (final p in (json['profiles'] as List? ?? const []))
        if (p is Map) Profile.fromJson(p.cast<String, Object?>()),
    ].where((p) => isValidProfileId(p.id)).toList();
    final main =
        list.where((p) => p.isMain).firstOrNull ??
        Profile(id: mainProfileId, name: mainName);
    return ProfileRegistry(
      profiles: [main, ...list.where((p) => !p.isMain)],
      lastUsedId: json['lastUsed'] as String? ?? mainProfileId,
      enabled: json['enabled'] as bool?,
    );
  }
}
