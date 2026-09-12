// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Lockspire

import 'dart:io' show Platform;

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../domain/ports/active_sync_provider_port.dart';
import '../../domain/ports/one_drive_account_port.dart';
import '../../infrastructure/google_drive_sync_adapter.dart';
import '../../infrastructure/one_drive_sync_adapter.dart';
import '../../infrastructure/webdav_sync_adapter.dart';
import '../../domain/ports/sync_port.dart';
import 'active_sync_provider_port_provider.dart';
import 'current_sync_credentials_provider.dart';
import 'google_drive_account_port_provider.dart';
import 'google_drive_android_auth_provider.dart';
import 'google_drive_windows_auth_provider.dart';
import 'microsoft_oauth_auth_provider.dart';
import 'one_drive_account_port_provider.dart';

part 'active_sync_port_provider.g.dart';

/// Arma el [SyncPort] del proveedor activo (ver `ActiveSyncProviderPort`).
/// `null` si no hay ninguno configurado, o si Google Drive está activo
/// pero la reconexión silenciosa falló (sesión revocada — el usuario
/// necesita reconectar desde `SyncSettingsScreen`).
@Riverpod(keepAlive: true)
Future<SyncPort?> activeSyncPort(Ref ref) async {
  final provider = await ref
      .watch(activeSyncProviderPortProvider)
      .activeProvider();

  switch (provider) {
    case SyncProviderId.webdav:
      final credentials = await ref.watch(
        currentSyncCredentialsProvider.future,
      );
      if (credentials == null) return null;
      return WebdavSyncAdapter(credentials);

    case SyncProviderId.googleDrive:
      final account = await ref
          .watch(googleDriveAccountPortProvider)
          .googleDriveAccount();
      if (account == null) return null;

      if (Platform.isWindows) {
        if (account.refreshToken == null) return null;
        final connection = await ref
            .watch(googleDriveWindowsAuthProvider)
            .reconnect(
              refreshToken: account.refreshToken!,
              email: account.email,
            );
        return GoogleDriveSyncAdapter(connection.httpClient);
      }

      final connection = await ref
          .watch(googleDriveAndroidAuthProvider)
          .reconnectSilently();
      if (connection == null) return null;
      return GoogleDriveSyncAdapter(connection.httpClient);

    case SyncProviderId.oneDrive:
      final accountPort = ref.watch(oneDriveAccountPortProvider);
      final account = await accountPort.oneDriveAccount();
      if (account == null) return null;

      final connection = await ref
          .watch(microsoftOauthAuthProvider)
          .reconnect(refreshToken: account.refreshToken, email: account.email);
      // Microsoft rota el refresh token en cada uso (cliente PKCE) — a
      // diferencia de Google, hay que volver a guardarlo si cambió o la
      // próxima sync falla con el token viejo ya invalidado.
      if (connection.refreshToken != account.refreshToken) {
        await accountPort.saveOneDriveAccount(
          OneDriveAccount(
            email: connection.email,
            refreshToken: connection.refreshToken,
          ),
        );
      }
      return OneDriveSyncAdapter(connection.accessToken);

    case null:
      return null;
  }
}
