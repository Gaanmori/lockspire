// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Gabriel Ángel Montoya Rico

import 'package:lockspire/shared/domain/profile_ids.dart';

export 'package:lockspire/shared/domain/profile_ids.dart'
    show mainProfileId, isValidProfileId;

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
