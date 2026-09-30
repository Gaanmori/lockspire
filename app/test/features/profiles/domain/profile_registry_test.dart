// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Gabriel Ángel Montoya Rico

import 'package:flutter_test/flutter_test.dart';
import 'package:lockspire/features/profiles/domain/profile.dart';
import 'package:lockspire/features/profiles/domain/profile_registry.dart';
import 'package:lockspire/shared/domain/app_problem.dart';

Matcher _problem(AppProblemCode code) =>
    throwsA(isA<AppProblem>().having((e) => e.code, 'code', code));

void main() {
  final initial = ProfileRegistry.initial(mainName: 'Principal');

  test('la instalación de siempre tiene solo el perfil principal, sin lista '
      'al abrir', () {
    expect(initial.profiles, [
      const Profile(id: mainProfileId, name: 'Principal'),
    ]);
    expect(initial.lastUsed.isMain, isTrue);
    expect(initial.showsPicker(defaultEnabled: true), isFalse);
  });

  test('agregar un perfil lo deja como el último usado y muestra la lista '
      'solo si están activados', () {
    final registry = initial.add(id: 'p2', name: '  María ');

    expect(registry.profiles.last, const Profile(id: 'p2', name: 'María'));
    expect(registry.lastUsed.id, 'p2');
    expect(registry.showsPicker(defaultEnabled: true), isTrue);
    expect(registry.showsPicker(defaultEnabled: false), isFalse);
    expect(
      registry.setEnabled(true).showsPicker(defaultEnabled: false),
      isTrue,
    );
  });

  test('los nombres no pueden estar vacíos, ser muy largos ni repetirse '
      '(sin importar mayúsculas)', () {
    expect(
      () => initial.add(id: 'x', name: '   '),
      _problem(AppProblemCode.profileNameEmpty),
    );
    expect(
      () => initial.add(id: 'x', name: 'a' * (maxProfileNameLength + 1)),
      _problem(AppProblemCode.profileNameTooLong),
    );
    expect(
      () => initial.add(id: 'x', name: 'PRINCIPAL'),
      _problem(AppProblemCode.profileNameTaken),
    );
  });

  test('renombrar conserva el id y admite el mismo nombre con otras '
      'mayúsculas', () {
    final registry = initial.add(id: 'p2', name: 'maria');

    final renamed = registry.rename('p2', 'María');
    expect(renamed.byId('p2')!.name, 'María');
    expect(
      () => renamed.rename('p2', 'Principal'),
      _problem(AppProblemCode.profileNameTaken),
    );
  });

  test('el principal no se borra; borrar el último usado vuelve al '
      'principal', () {
    final registry = initial.add(id: 'p2', name: 'Demo');

    expect(
      () => registry.remove(mainProfileId),
      _problem(AppProblemCode.profileMainNotRemovable),
    );
    final removed = registry.remove('p2');
    expect(removed.profiles, hasLength(1));
    expect(removed.lastUsed.isMain, isTrue);
  });

  test('no se desactivan con más de un perfil: los demás quedarían '
      'inaccesibles', () {
    final registry = initial.setEnabled(true).add(id: 'p2', name: 'Demo');

    expect(
      () => registry.setEnabled(false),
      _problem(AppProblemCode.profilesInUse),
    );
    expect(registry.remove('p2').setEnabled(false).enabled, isFalse);
  });

  test(
    'se guarda y se lee igual; si el principal falta, se repone primero',
    () {
      final registry = initial
          .add(id: 'p2', name: 'María')
          .setEnabled(true)
          .select(mainProfileId);

      final read = ProfileRegistry.fromJson(
        registry.toJson(),
        mainName: 'otro',
      );
      expect(read.profiles, registry.profiles);
      expect(read.lastUsedId, mainProfileId);
      expect(read.enabled, isTrue);

      final corrupt = ProfileRegistry.fromJson({
        'profiles': [
          {'id': 'p2', 'name': 'María'},
        ],
        'lastUsed': 'no-existe',
      }, mainName: 'Principal');
      expect(corrupt.main.isMain, isTrue);
      expect(corrupt.profiles.map((p) => p.id), [mainProfileId, 'p2']);
      expect(corrupt.lastUsed.isMain, isTrue);
    },
  );

  test('elegir un perfil que no existe es un error de programación', () {
    expect(() => initial.select('no-existe'), throwsArgumentError);
    expect(
      () => initial.add(id: mainProfileId, name: 'Otro'),
      throwsArgumentError,
    );
  });
}
