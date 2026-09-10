// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Lockspire

import 'dart:io' show Platform;

import 'package:lockspire/features/vault/domain/entities/vault_entry.dart';
import 'package:lockspire/features/vault/presentation/providers/crypto_port_provider.dart';
import 'package:lockspire/features/vault/presentation/providers/vault_storage_port_provider.dart';
import 'package:lockspire/features/vault/presentation/vault_session_controller.dart';
import 'package:lockspire/features/vault/presentation/vault_session_state.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../application/sync_vault_use_case.dart';
import '../domain/ports/active_sync_provider_port.dart';
import '../domain/ports/google_drive_account_port.dart';
import '../domain/ports/sync_credentials_port.dart';
import 'providers/active_sync_port_provider.dart';
import 'providers/active_sync_provider_port_provider.dart';
import 'providers/current_google_drive_account_provider.dart';
import 'providers/current_sync_credentials_provider.dart';
import 'providers/google_drive_account_port_provider.dart';
import 'providers/google_drive_android_auth_provider.dart';
import 'providers/google_drive_windows_auth_provider.dart';
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
    await ref
        .read(activeSyncProviderPortProvider)
        .saveActiveProvider(SyncProviderId.webdav);
    ref.invalidate(currentSyncCredentialsProvider);
    ref.invalidate(activeSyncPortProvider);
  }

  /// Conexión interactiva con Google Drive — dispara el flujo nativo en
  /// Android (`google_sign_in`) o abre el navegador en Windows (loopback
  /// OAuth). Elegir Google Drive acá implica "usar Google Drive" — pasa a
  /// ser el proveedor activo.
  Future<void> connectGoogleDrive() async {
    final connection = Platform.isWindows
        ? await ref.read(googleDriveWindowsAuthProvider).connectInteractive()
        : await ref.read(googleDriveAndroidAuthProvider).connectInteractive();

    await ref
        .read(googleDriveAccountPortProvider)
        .saveGoogleDriveAccount(
          GoogleDriveAccount(
            email: connection.email,
            refreshToken: connection.refreshToken,
          ),
        );
    await ref
        .read(activeSyncProviderPortProvider)
        .saveActiveProvider(SyncProviderId.googleDrive);
    ref.invalidate(currentGoogleDriveAccountProvider);
    ref.invalidate(activeSyncPortProvider);
  }

  /// Desconecta la cuenta de Google — si era el proveedor activo, deja de
  /// haber ninguno configurado (no cae de vuelta a WebDAV solo).
  Future<void> disconnectGoogleDrive() async {
    if (!Platform.isWindows) {
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
    ref.invalidate(activeSyncPortProvider);
  }

  Future<void> syncNow() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final useCase = await _buildUseCase();
      final result = await useCase.call();
      await _reloadSessionIfNeeded(result);
      return result;
    });
  }

  /// Segundo paso tras un `SyncNeedsResolution` — la UI (picker de
  /// conflictos) junta una resolución por cada entrada en conflicto y
  /// llama acá para terminar la sincronización.
  Future<void> completeMerge(
    SyncNeedsResolution pending,
    Map<String, VaultEntry> resolutions,
  ) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final useCase = await _buildUseCase();
      final result = await useCase.completeMerge(pending, resolutions);
      await _reloadSessionIfNeeded(result);
      return result;
    });
  }

  Future<SyncVaultUseCase> _buildUseCase() async {
    final session = ref.read(vaultSessionControllerProvider).value;
    if (session is! VaultSessionUnlocked) {
      throw StateError(
        'La bóveda tiene que estar desbloqueada para sincronizar',
      );
    }

    final syncPort = await ref.read(activeSyncPortProvider.future);
    if (syncPort == null) {
      throw StateError(
        'Configurá un proveedor de sync primero (WebDAV o Google Drive)',
      );
    }

    return SyncVaultUseCase(
      localStorage: await ref.read(vaultStoragePortProvider.future),
      ancestorStorage: await ref.read(syncAncestorStoragePortProvider.future),
      remote: syncPort,
      syncState: ref.read(syncStatePortProvider),
      crypto: await ref.read(cryptoPortProvider.future),
      key: session.key,
      header: session.header,
    );
  }

  /// Si la sync escribió contenido local nuevo (descarga o merge), la
  /// sesión en memoria queda desactualizada respecto al archivo en disco
  /// — se refresca acá. Nunca hace falta para `SyncUploaded`/`SyncUpToDate`
  /// (el local no cambió) ni para `SyncNeedsResolution` (todavía no se
  /// escribió nada).
  Future<void> _reloadSessionIfNeeded(SyncResult result) async {
    if (result is SyncDownloaded || result is SyncMerged) {
      await ref.read(vaultSessionControllerProvider.notifier).reloadFromDisk();
    }
  }
}
