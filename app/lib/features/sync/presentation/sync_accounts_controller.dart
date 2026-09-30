// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Gabriel Ángel Montoya Rico

import 'package:lockspire/features/vault/presentation/auto_lock_controller.dart';
import 'package:lockspire/features/vault/presentation/providers/crypto_port_provider.dart';
import 'package:lockspire/features/vault/presentation/providers/vault_storage_port_provider.dart';
import 'package:lockspire/features/vault/presentation/vault_session_controller.dart';
import 'package:lockspire/features/vault/presentation/vault_session_state.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../application/move_vault_to_provider_use_case.dart';
import '../application/sync_vault_use_case.dart';
import '../domain/ports/active_sync_provider_port.dart';
import '../domain/ports/cloud_sign_in_port.dart';
import '../domain/ports/google_drive_account_port.dart';
import '../domain/ports/one_drive_account_port.dart';
import '../domain/ports/sync_credentials_port.dart';
import 'providers/active_sync_port_provider.dart';
import 'providers/active_sync_provider_port_provider.dart';
import 'providers/cloud_sign_in_providers.dart';
import 'providers/current_active_sync_provider_provider.dart';
import 'providers/current_google_drive_account_provider.dart';
import 'providers/current_one_drive_account_provider.dart';
import 'providers/current_sync_credentials_provider.dart';
import 'providers/google_drive_account_port_provider.dart';
import 'providers/is_sync_configured_provider.dart';
import 'providers/one_drive_account_port_provider.dart';
import 'providers/sync_ancestor_storage_port_provider.dart';
import 'providers/sync_credentials_port_provider.dart';
import 'providers/sync_state_port_provider.dart';
import 'package:lockspire/shared/domain/app_problem.dart';

part 'sync_accounts_controller.g.dart';

@Riverpod(keepAlive: true)
SyncAccountsController syncAccountsController(Ref ref) =>
    SyncAccountsController(ref);

/// Qué nubes están conectadas en este dispositivo y cuál es la activa:
/// conectar y desconectar cuentas, y mudar la bóveda entre nubes (ADR
/// 0023). Separado de `SyncController`, que sincroniza (revisión
/// 2026-09-28, A9).
class SyncAccountsController {
  final Ref _ref;

  SyncAccountsController(this._ref);

  Future<void> saveCredentials(WebDavCredentials credentials) async {
    await _ref.read(syncCredentialsPortProvider).save(credentials);
    _ref.invalidate(currentSyncCredentialsProvider);
    await _activate(SyncProviderId.webdav);
  }

  /// El login abre el selector de cuentas o el navegador: sin bloquear
  /// la bóveda mientras tanto, o se perdería la respuesta.
  Future<CloudSignIn> _signIn(ProviderListenable<CloudSignInPort> port) {
    final signIn = _ref.read(port);
    return _ref
        .read(autoLockControllerProvider)
        .whileInSystemUi(signIn.connect);
  }

  /// Conexión interactiva con Google Drive — dispara el flujo nativo en
  /// Android (`google_sign_in`) o abre el navegador en escritorio — Windows
  /// y Linux (loopback OAuth). Elegir Google Drive acá implica "usar
  /// Google Drive" — pasa a ser el proveedor activo.
  Future<void> connectGoogleDrive() async {
    final connection = await _signIn(googleDriveSignInPortProvider);
    await _ref
        .read(googleDriveAccountPortProvider)
        .saveGoogleDriveAccount(
          GoogleDriveAccount(
            email: connection.email,
            refreshToken: connection.refreshToken,
          ),
        );
    _ref.invalidate(currentGoogleDriveAccountProvider);
    await _activate(SyncProviderId.googleDrive);
  }

  /// Desconecta la cuenta de Google — si era el proveedor activo, deja de
  /// haber ninguno configurado (no cae de vuelta a WebDAV solo).
  Future<void> disconnectGoogleDrive() async {
    await _ref.read(googleDriveSignInPortProvider).disconnect();
    await _ref.read(googleDriveAccountPortProvider).clearGoogleDriveAccount();
    _ref.invalidate(currentGoogleDriveAccountProvider);
    await _deactivateIfActive(SyncProviderId.googleDrive);
  }

  /// Conexión interactiva con OneDrive — abre el navegador del sistema en
  /// todas las plataformas (ver `microsoft_oauth_auth.dart`). Elegir
  /// OneDrive acá implica "usar OneDrive" — pasa a ser el proveedor activo.
  Future<void> connectOneDrive() async {
    final connection = await _signIn(oneDriveSignInPortProvider);
    final refreshToken = connection.refreshToken;
    // Sin refresh token no se podría volver a conectar en cada sync.
    if (refreshToken == null) {
      throw const AppProblem(
        AppProblemCode.oauthTokenFailed,
        detail: 'OneDrive',
      );
    }
    await _ref
        .read(oneDriveAccountPortProvider)
        .saveOneDriveAccount(
          OneDriveAccount(email: connection.email, refreshToken: refreshToken),
        );
    _ref.invalidate(currentOneDriveAccountProvider);
    await _activate(SyncProviderId.oneDrive);
  }

  /// Desconecta la cuenta de OneDrive (mismo criterio que
  /// [disconnectGoogleDrive]).
  Future<void> disconnectOneDrive() async {
    await _ref.read(oneDriveSignInPortProvider).disconnect();
    await _ref.read(oneDriveAccountPortProvider).clearOneDriveAccount();
    _ref.invalidate(currentOneDriveAccountProvider);
    await _deactivateIfActive(SyncProviderId.oneDrive);
  }

  /// Muda la bóveda a [to] (ADR 0023), o le fija su nube por primera vez
  /// si [from] es `null` (bóvedas anteriores a ese ADR, ver
  /// `SyncController.syncNow`).
  Future<void> moveVault({
    required SyncProviderId? from,
    required SyncProviderId to,
  }) async {
    final session = _ref.read(vaultSessionControllerProvider).value;
    if (session is! VaultSessionUnlocked) {
      throw const AppProblem(AppProblemCode.vaultLocked);
    }
    final toPort = await freshSyncPortFor(_ref, to);
    if (toPort == null) {
      throw AppProblem(
        AppProblemCode.syncConnectFailed,
        detail: syncProviderName(to),
      );
    }
    final fromPort = from == null ? null : await freshSyncPortFor(_ref, from);
    await MoveVaultToProviderUseCase(
      localStorage: await _ref.read(vaultStoragePortProvider.future),
      ancestorStorage: await _ref.read(syncAncestorStoragePortProvider.future),
      syncState: _ref.read(syncStatePortProvider),
      crypto: await _ref.read(cryptoPortProvider.future),
      key: session.key,
      header: session.header,
      from: fromPort,
      fromId: fromPort == null ? null : from,
      to: toPort,
      toId: to,
    ).call();
    await _ref.read(vaultSessionControllerProvider.notifier).reloadFromDisk();
  }

  /// Activa [id] como nube de sync. Con la bóveda desbloqueada es una
  /// **mudanza** (ADR 0023): la bóveda pasa a vivir en [id] y la nube
  /// anterior recibe el aviso. Si está bloqueada o no existe (restaurar en
  /// un dispositivo nuevo), solo la activa.
  Future<void> _activate(SyncProviderId id) async {
    final activePort = _ref.read(activeSyncProviderPortProvider);
    final previous = await activePort.activeProvider();
    _ref.invalidate(syncPortForProvider);
    final session = _ref.read(vaultSessionControllerProvider).value;
    if (session is VaultSessionUnlocked) {
      final moving = previous != null && previous != id;
      if (moving || session.vault.syncHome != id.name) {
        await moveVault(from: moving ? previous : null, to: id);
      }
    }
    await activePort.saveActiveProvider(id);
    _invalidateActive();
  }

  /// Desconectar la nube activa deja sin ninguna configurada.
  Future<void> _deactivateIfActive(SyncProviderId id) async {
    final activePort = _ref.read(activeSyncProviderPortProvider);
    if (await activePort.activeProvider() == id) {
      await activePort.clearActiveProvider();
    }
    _invalidateActive();
  }

  void _invalidateActive() {
    _ref
      ..invalidate(currentActiveSyncProviderProvider)
      ..invalidate(activeSyncPortProvider)
      ..invalidate(isSyncConfiguredProvider);
  }
}
