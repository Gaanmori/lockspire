// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Gabriel Ángel Montoya Rico

import 'package:lockspire/shared/active_profile_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:uuid/uuid.dart';

import '../domain/profile.dart';
import '../domain/profile_registry.dart';
import 'providers/profile_providers.dart';

part 'profiles_controller.g.dart';

/// Los perfiles del dispositivo (ADR 0039). Abrir, agregar o borrar uno
/// cambia de contenedor: después de `ProfileSwitcher.open` este controlador
/// ya no existe, así que es siempre lo último que se hace.
@Riverpod(keepAlive: true)
class ProfilesController extends _$ProfilesController {
  /// El nombre del principal queda vacío hasta que el usuario lo cambie: la
  /// pantalla muestra "Principal" en el idioma de la app.
  @override
  Future<ProfileRegistry> build() =>
      ref.watch(profileRegistryPortProvider).load(mainName: '');

  Future<void> open(String id) async {
    if (id == ref.read(activeProfileIdProvider)) return;
    final switcher = ref.read(profileSwitcherProvider);
    await _save((await future).select(id));
    await switcher.open(id);
  }

  /// Agrega un perfil vacío y lo abre: ahí se crea o restaura su bóveda.
  /// [mainDisplayName]: ver `ProfileRegistry.add`.
  Future<void> add(String name, {required String mainDisplayName}) async {
    final switcher = ref.read(profileSwitcherProvider);
    final id = const Uuid().v4();
    await _save(
      (await future).add(id: id, name: name, mainDisplayName: mainDisplayName),
    );
    await switcher.open(id);
  }

  Future<void> renameActive(
    String name, {
    required String mainDisplayName,
  }) async {
    final id = ref.read(activeProfileIdProvider);
    await _save(
      (await future).rename(id, name, mainDisplayName: mainDisplayName),
    );
  }

  Future<void> setEnabled(bool enabled) async {
    await _save((await future).setEnabled(enabled));
  }

  /// Borra el perfil abierto (nunca el principal): la sesión desbloqueada
  /// prueba que se conoce su contraseña. Se vuelve al principal y, con este
  /// perfil ya cerrado, se borran su bóveda y sus claves.
  Future<void> deleteActive() async {
    final id = ref.read(activeProfileIdProvider);
    final switcher = ref.read(profileSwitcherProvider);
    final data = ref.read(profileDataPortProvider);
    await _save((await future).remove(id));
    await switcher.open(mainProfileId, afterLeaving: () => data.erase(id));
  }

  Future<void> _save(ProfileRegistry registry) async {
    await ref.read(profileRegistryPortProvider).save(registry);
    state = AsyncData(registry);
  }
}

/// El perfil abierto, con su nombre.
@Riverpod(keepAlive: true)
Profile? activeProfile(Ref ref) => ref
    .watch(profilesControllerProvider)
    .value
    ?.byId(ref.watch(activeProfileIdProvider));

/// Si la lista de perfiles se muestra (desbloqueo, crear bóveda).
@Riverpod(keepAlive: true)
bool showsProfilePicker(Ref ref) =>
    ref
        .watch(profilesControllerProvider)
        .value
        ?.showsPicker(
          defaultEnabled: ref.watch(profilesEnabledByDefaultProvider),
        ) ??
    false;

/// Si los perfiles están activados (Ajustes → Perfiles).
@Riverpod(keepAlive: true)
bool profilesEnabled(Ref ref) =>
    ref
        .watch(profilesControllerProvider)
        .value
        ?.isEnabled(
          defaultEnabled: ref.watch(profilesEnabledByDefaultProvider),
        ) ??
    ref.watch(profilesEnabledByDefaultProvider);
