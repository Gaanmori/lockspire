// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Gabriel Ángel Montoya Rico

import 'package:lockspire/features/vault/presentation/providers/vault_file_path_provider.dart';
import 'package:lockspire/shared/platform_capabilities.dart';
import 'package:lockspire/shared/secure_storage_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../domain/ports/profile_data_port.dart';
import '../../domain/ports/profile_registry_port.dart';
import '../../infrastructure/local_profile_data_adapter.dart';
import '../../infrastructure/secure_storage_profile_registry_adapter.dart';
import '../profile_switcher.dart';

part 'profile_providers.g.dart';

@Riverpod(keepAlive: true)
ProfileRegistryPort profileRegistryPort(Ref ref) =>
    SecureStorageProfileRegistryAdapter(ref.watch(deviceSecureStorageProvider));

@Riverpod(keepAlive: true)
ProfileDataPort profileDataPort(Ref ref) => LocalProfileDataAdapter(
  ref.watch(deviceSecureStorageProvider),
  () => ref.read(appDataDirectoryProvider.future),
);

/// Si los perfiles vienen activados sin que el usuario elija: sí en
/// escritorio, no en Android, donde es raro compartir el teléfono.
@Riverpod(keepAlive: true)
bool profilesEnabledByDefault(Ref ref) =>
    !ref.watch(platformCapabilitiesProvider).isAndroid;

/// Lo reemplaza `ProfileHost` al crear cada contenedor. Sin él (tests de
/// una sola pantalla) no hay a dónde cambiar.
@Riverpod(keepAlive: true)
ProfileSwitcher profileSwitcher(Ref ref) => const _NoProfileHost();

class _NoProfileHost implements ProfileSwitcher {
  const _NoProfileHost();

  @override
  Future<void> open(
    String profileId, {
    Future<void> Function()? afterLeaving,
  }) => throw UnsupportedError('Sin ProfileHost no se cambia de perfil');
}
