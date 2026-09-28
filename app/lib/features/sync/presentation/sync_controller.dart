// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Lockspire

import 'package:lockspire/features/vault/presentation/providers/crypto_port_provider.dart';
import 'package:lockspire/features/vault/presentation/providers/vault_storage_port_provider.dart';
import 'package:lockspire/features/vault/presentation/vault_session_controller.dart';
import 'package:lockspire/features/vault/presentation/vault_session_state.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../application/adopt_remote_master_password_use_case.dart';
import '../application/move_vault_to_provider_use_case.dart';
import '../application/sync_vault_use_case.dart';
import '../domain/ports/active_sync_provider_port.dart';
import '../domain/ports/google_drive_account_port.dart';
import '../domain/ports/one_drive_account_port.dart';
import '../domain/ports/sync_port.dart';
import '../domain/ports/sync_credentials_port.dart';
import '../infrastructure/google_drive_desktop_auth.dart';
import 'providers/active_sync_port_provider.dart';
import 'providers/active_sync_provider_port_provider.dart';
import 'providers/current_active_sync_provider_provider.dart';
import 'providers/current_google_drive_account_provider.dart';
import 'providers/current_one_drive_account_provider.dart';
import 'providers/current_sync_credentials_provider.dart';
import 'providers/google_drive_account_port_provider.dart';
import 'providers/google_drive_android_auth_provider.dart';
import 'providers/google_drive_desktop_auth_provider.dart';
import 'providers/is_sync_configured_provider.dart';
import 'providers/microsoft_oauth_auth_provider.dart';
import 'providers/one_drive_account_port_provider.dart';
import 'providers/sync_ancestor_storage_port_provider.dart';
import 'providers/sync_credentials_port_provider.dart';
import 'providers/sync_state_port_provider.dart';

part 'sync_controller.g.dart';

/// Guardar credenciales y disparar sync manual (o automática, ver
/// `VaultSessionController._maybeSyncNow`). `null` en el estado significa
/// "todavía no se intentó sincronizar en esta sesión" — no es un error.
@Riverpod(keepAlive: true)
class SyncController extends _$SyncController {
  @override
  Future<SyncResult?> build() async => null;

  Future<void> saveCredentials(WebDavCredentials credentials) async {
    await ref.read(syncCredentialsPortProvider).save(credentials);
    ref.invalidate(currentSyncCredentialsProvider);
    await _activateProvider(SyncProviderId.webdav);
    ref.invalidate(currentActiveSyncProviderProvider);
    ref.invalidate(activeSyncPortProvider);
    ref.invalidate(isSyncConfiguredProvider);
  }

  /// Conexión interactiva con Google Drive — dispara el flujo nativo en
  /// Android (`google_sign_in`) o abre el navegador en escritorio — Windows
  /// y Linux (loopback OAuth). Elegir Google Drive acá implica "usar
  /// Google Drive" — pasa a ser el proveedor activo.
  Future<void> connectGoogleDrive() async {
    final connection = usesDesktopGoogleAuth
        ? await ref.read(googleDriveDesktopAuthProvider).connectInteractive()
        : await ref.read(googleDriveAndroidAuthProvider).connectInteractive();

    await ref
        .read(googleDriveAccountPortProvider)
        .saveGoogleDriveAccount(
          GoogleDriveAccount(
            email: connection.email,
            refreshToken: connection.refreshToken,
          ),
        );
    ref.invalidate(currentGoogleDriveAccountProvider);
    await _activateProvider(SyncProviderId.googleDrive);
    ref.invalidate(currentActiveSyncProviderProvider);
    ref.invalidate(activeSyncPortProvider);
    ref.invalidate(isSyncConfiguredProvider);
  }

  /// Desconecta la cuenta de Google — si era el proveedor activo, deja de
  /// haber ninguno configurado (no cae de vuelta a WebDAV solo).
  Future<void> disconnectGoogleDrive() async {
    if (!usesDesktopGoogleAuth) {
      await ref.read(googleDriveAndroidAuthProvider).disconnect();
    }
    await ref.read(googleDriveAccountPortProvider).clearGoogleDriveAccount();
    final active = await ref
        .read(activeSyncProviderPortProvider)
        .activeProvider();
    if (active == SyncProviderId.googleDrive) {
      await ref.read(activeSyncProviderPortProvider).clearActiveProvider();
    }
    ref.invalidate(currentGoogleDriveAccountProvider);
    ref.invalidate(currentActiveSyncProviderProvider);
    ref.invalidate(activeSyncPortProvider);
    ref.invalidate(isSyncConfiguredProvider);
  }

  /// Conexión interactiva con OneDrive — abre el navegador del sistema en
  /// todas las plataformas (ver `microsoft_oauth_auth.dart`, a diferencia
  /// de Google Drive no hay split Android/escritorio acá). Elegir OneDrive acá
  /// implica "usar OneDrive" — pasa a ser el proveedor activo.
  Future<void> connectOneDrive() async {
    final connection = await ref
        .read(microsoftOauthAuthProvider)
        .connectInteractive();

    await ref
        .read(oneDriveAccountPortProvider)
        .saveOneDriveAccount(
          OneDriveAccount(
            email: connection.email,
            refreshToken: connection.refreshToken,
          ),
        );
    ref.invalidate(currentOneDriveAccountProvider);
    await _activateProvider(SyncProviderId.oneDrive);
    ref.invalidate(currentActiveSyncProviderProvider);
    ref.invalidate(activeSyncPortProvider);
    ref.invalidate(isSyncConfiguredProvider);
  }

  /// Desconecta la cuenta de OneDrive — si era el proveedor activo, deja
  /// de haber ninguno configurado (mismo criterio que
  /// `disconnectGoogleDrive()`).
  Future<void> disconnectOneDrive() async {
    await ref.read(oneDriveAccountPortProvider).clearOneDriveAccount();
    final active = await ref
        .read(activeSyncProviderPortProvider)
        .activeProvider();
    if (active == SyncProviderId.oneDrive) {
      await ref.read(activeSyncProviderPortProvider).clearActiveProvider();
    }
    ref.invalidate(currentOneDriveAccountProvider);
    ref.invalidate(currentActiveSyncProviderProvider);
    ref.invalidate(activeSyncPortProvider);
    ref.invalidate(isSyncConfiguredProvider);
  }

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
        await _moveVault(from: null, to: useCase.activeProvider!);
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

  /// Activa [id] como nube de sync. Con la bóveda desbloqueada es una
  /// **mudanza** (ADR 0023): la bóveda pasa a vivir en [id] y la nube
  /// anterior recibe el aviso. Si está bloqueada o no existe (restaurar en
  /// un dispositivo nuevo), solo la activa.
  Future<void> _activateProvider(SyncProviderId id) async {
    final activePort = ref.read(activeSyncProviderPortProvider);
    final previous = await activePort.activeProvider();
    ref.invalidate(syncPortForProvider);
    final session = ref.read(vaultSessionControllerProvider).value;
    if (session is VaultSessionUnlocked) {
      final moving = previous != null && previous != id;
      if (moving || session.vault.syncHome != id.name) {
        await _moveVault(from: moving ? previous : null, to: id);
      }
    }
    await activePort.saveActiveProvider(id);
    ref.invalidate(currentActiveSyncProviderProvider);
    ref.invalidate(activeSyncPortProvider);
    ref.invalidate(isSyncConfiguredProvider);
  }

  Future<void> _moveVault({
    required SyncProviderId? from,
    required SyncProviderId to,
  }) async {
    final session = _requireUnlockedSession();
    final toPort = await ref.read(syncPortForProvider(to).future);
    if (toPort == null) {
      throw StateError('No se pudo conectar con ${syncProviderName(to)}.');
    }
    final fromPort = from == null
        ? null
        : await ref.read(syncPortForProvider(from).future);
    await MoveVaultToProviderUseCase(
      localStorage: await ref.read(vaultStoragePortProvider.future),
      ancestorStorage: await ref.read(syncAncestorStoragePortProvider.future),
      syncState: ref.read(syncStatePortProvider),
      crypto: await ref.read(cryptoPortProvider.future),
      key: session.key,
      header: session.header,
      from: fromPort,
      fromId: fromPort == null ? null : from,
      to: toPort,
      toId: to,
    ).call();
    await ref.read(vaultSessionControllerProvider.notifier).reloadFromDisk();
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
      throw StateError(
        'La bóveda tiene que estar desbloqueada para sincronizar',
      );
    }
    return session;
  }

  Future<SyncPort> _requireSyncPort() async {
    final syncPort = await ref.read(activeSyncPortProvider.future);
    if (syncPort == null) {
      throw StateError(
        'Configure un proveedor de sync primero (WebDAV, Google Drive u OneDrive)',
      );
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
