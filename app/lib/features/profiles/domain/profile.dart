// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Gabriel Ángel Montoya Rico

/// Id del perfil que ya existía antes de los perfiles (ADR 0039): conserva
/// la ruta de su bóveda y sus claves sin prefijo.
const mainProfileId = 'principal';

/// Una bóveda del dispositivo con sus propios ajustes (ADR 0039).
class Profile {
  final String id;
  final String name;

  const Profile({required this.id, required this.name});

  bool get isMain => id == mainProfileId;

  Profile renamed(String name) => Profile(id: id, name: name);

  Map<String, Object?> toJson() => {'id': id, 'name': name};

  factory Profile.fromJson(Map<String, Object?> json) =>
      Profile(id: json['id']! as String, name: json['name']! as String);

  @override
  bool operator ==(Object other) =>
      other is Profile && other.id == id && other.name == name;

  @override
  int get hashCode => Object.hash(id, name);

  @override
  String toString() => 'Profile($id, $name)';
}
