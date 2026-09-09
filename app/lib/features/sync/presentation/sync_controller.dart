// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Lockspire

import 'package:lockspire/features/vault/presentation/providers/vault_storage_port_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../application/sync_vault_use_case.dart';
import '../domain/ports/sync_credentials_port.dart';
import 'providers/current_sync_credentials_provider.dart';
import 'providers/sync_credentials_port_provider.dart';
import 'providers/sync_state_port_provider.dart';
import 'providers/webdav_sync_port_provider.dart';

part 'sync_controller.g.dart';

/// Guardar credenciales y disparar sync manual. `null` en el estado
/// significa "todavía no se intentó sincronizar en esta sesión" — no es
/// un error.
@Riverpod(keepAlive: true)
class SyncController extends _$SyncController {
  @override
  Future<SyncResult?> build() async => null;

  Future<void> saveCredentials(WebDavCredentials credentials) async {
    await ref.read(syncCredentialsPortProvider).save(credentials);
    ref.invalidate(currentSyncCredentialsProvider);
    ref.invalidate(webdavSyncPortProvider);
  }

  Future<void> syncNow() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final syncPort = await ref.read(webdavSyncPortProvider.future);
      if (syncPort == null) {
        throw StateError('Configurá el servidor WebDAV primero');
      }
      final localStorage = await ref.read(vaultStoragePortProvider.future);
      final syncState = ref.read(syncStatePortProvider);

      return SyncVaultUseCase(
        localStorage: localStorage,
        remote: syncPort,
        syncState: syncState,
      )();
    });
  }
}
