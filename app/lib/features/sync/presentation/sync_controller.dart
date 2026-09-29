// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Gabriel Ángel Montoya Rico

import 'package:lockspire/features/vault/presentation/providers/crypto_port_provider.dart';
import 'package:lockspire/features/vault/presentation/providers/vault_storage_port_provider.dart';
import 'package:lockspire/features/vault/presentation/vault_session_controller.dart';
import 'package:lockspire/features/vault/presentation/vault_session_state.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../application/adopt_remote_master_password_use_case.dart';
import '../application/sync_vault_use_case.dart';
import '../domain/ports/sync_port.dart';
import 'providers/active_sync_port_provider.dart';
import 'sync_accounts_controller.dart';
import 'providers/current_active_sync_provider_provider.dart';
import 'providers/sync_ancestor_storage_port_provider.dart';
import 'providers/sync_state_port_provider.dart';
import 'package:lockspire/shared/domain/app_problem.dart';

part 'sync_controller.g.dart';

/// Sincronizar (manual o automática, ver `AutoSyncController`), reemplazar
/// la nube con lo local y adoptar una contraseña cambiada en otro
/// dispositivo. Conectar y desconectar nubes está en
/// `SyncAccountsController` (revisión 2026-09-28, A9). `null` en el estado
/// significa "todavía no se intentó sincronizar en esta sesión" — no es un
/// error.
@Riverpod(keepAlive: true)
class SyncController extends _$SyncController {
  @override
  Future<SyncResult?> build() async => null;

  Future<void> syncNow() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final useCase = await _buildUseCase();
      final result = await useCase.call();
      await _reloadSessionIfNeeded(result);
      // Bóveda anterior a ADR 0023: se le fija la nube con la que sincroniza.
      final session = ref.read(vaultSessionControllerProvider).value;
      if (result is! SyncVaultMoved &&
          session is VaultSessionUnlocked &&
          session.vault.syncHome == null &&
          useCase.activeProvider != null) {
        await ref
            .read(syncAccountsControllerProvider)
            .moveVault(from: null, to: useCase.activeProvider!);
      }
      return result;
    });
    await _rememberPasswordChangedElsewhere();
  }

  /// Anota si la contraseña cambió en otro dispositivo, para pedirla al
  /// abrir la app sin biometría (ADR 0024). Solo escribe si cambia.
  Future<void> _rememberPasswordChangedElsewhere() async {
    final error = state.error;
    final changed =
        error is RemoteVaultRejectedException &&
        error.reason == RemoteVaultRejection.passwordChanged;
    if (!changed && state.hasError) return;
    final syncState = ref.read(syncStatePortProvider);
    if (await syncState.passwordChangedElsewhere() != changed) {
      await syncState.setPasswordChangedElsewhere(changed);
    }
  }

  /// Tras un `RemoteVaultRejection.rollback`, con confirmación del usuario:
  /// reemplaza la nube con la bóveda de este dispositivo (ADR 0019).
  Future<void> replaceRemoteWithLocal() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () async => (await _buildUseCase()).replaceRemoteWithLocal(),
    );
  }

  /// Tras un `RemoteVaultRejection.passwordChanged`: adopta la contraseña
  /// maestra que se cambió en otro dispositivo (ADR 0018). Lanza
  /// `IncorrectMasterPasswordException` si [newPassword] no abre la bóveda
  /// de la nube; en ese caso no se cambió nada.
  Future<void> adoptRemoteMasterPassword(String newPassword) async {
    final session = _requireUnlockedSession();
    final syncPort = await _requireSyncPort();
    final result = await AdoptRemoteMasterPasswordUseCase(
      localStorage: await ref.read(vaultStoragePortProvider.future),
      ancestorStorage: await ref.read(syncAncestorStoragePortProvider.future),
      remote: syncPort,
      syncState: ref.read(syncStatePortProvider),
      crypto: await ref.read(cryptoPortProvider.future),
      currentKey: session.key,
      currentHeader: session.header,
    ).call(newPassword: newPassword);
    await ref
        .read(vaultSessionControllerProvider.notifier)
        .adoptRekeyedSession(result);
    state = const AsyncData(SyncDownloaded());
  }

  VaultSessionUnlocked _requireUnlockedSession() {
    final session = ref.read(vaultSessionControllerProvider).value;
    if (session is! VaultSessionUnlocked) {
      throw const AppProblem(AppProblemCode.vaultLocked);
    }
    return session;
  }

  Future<SyncPort> _requireSyncPort() async {
    final syncPort = await freshActiveSyncPort(ref);
    if (syncPort == null) {
      throw const AppProblem(AppProblemCode.syncNotConfigured);
    }
    return syncPort;
  }

  Future<SyncVaultUseCase> _buildUseCase() async {
    final session = _requireUnlockedSession();
    final syncPort = await _requireSyncPort();

    return SyncVaultUseCase(
      localStorage: await ref.read(vaultStoragePortProvider.future),
      ancestorStorage: await ref.read(syncAncestorStoragePortProvider.future),
      remote: syncPort,
      syncState: ref.read(syncStatePortProvider),
      crypto: await ref.read(cryptoPortProvider.future),
      key: session.key,
      header: session.header,
      activeProvider: await ref.read(currentActiveSyncProviderProvider.future),
    );
  }

  /// Si la sync escribió contenido local nuevo (descarga o merge), la
  /// sesión en memoria queda desactualizada respecto al archivo en disco
  /// — se refresca acá. Nunca hace falta para `SyncUploaded`/`SyncUpToDate`
  /// (el local no cambió).
  Future<void> _reloadSessionIfNeeded(SyncResult result) async {
    if (result is SyncDownloaded ||
        result is SyncMerged ||
        result is SyncVaultMoved) {
      await ref.read(vaultSessionControllerProvider.notifier).reloadFromDisk();
    }
  }
}
