// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Gabriel Ángel Montoya Rico

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../domain/ports/active_sync_provider_port.dart';
import '../../domain/ports/one_drive_account_port.dart';
import '../../infrastructure/google_drive_desktop_auth.dart';
import '../../infrastructure/google_drive_sync_adapter.dart';
import '../../infrastructure/one_drive_sync_adapter.dart';
import '../../infrastructure/webdav_sync_adapter.dart';
import '../../domain/ports/sync_port.dart';
import 'active_sync_provider_port_provider.dart';
import 'current_sync_credentials_provider.dart';
import 'google_drive_account_port_provider.dart';
import 'google_drive_android_auth_provider.dart';
import 'google_drive_desktop_auth_provider.dart';
import 'microsoft_oauth_auth_provider.dart';
import 'one_drive_account_port_provider.dart';

part 'active_sync_port_provider.g.dart';

/// Arma el [SyncPort] del proveedor activo (ver `ActiveSyncProviderPort`).
/// `null` si no hay ninguno configurado, o si Google Drive está activo
/// pero la reconexión silenciosa falló (sesión revocada — el usuario
/// necesita reconectar desde `SyncSettingsScreen`).
/// El puerto de la nube activa en este dispositivo.
@Riverpod(keepAlive: true)
Future<SyncPort?> activeSyncPort(Ref ref) async {
  final provider = await ref
      .watch(activeSyncProviderPortProvider)
      .activeProvider();
  if (provider == null) return null;
  return ref.watch(syncPortForProvider(provider).future);
}

/// El puerto de la nube activa armado **de nuevo**, con un token fresco.
///
/// Los puertos llevan un token de acceso que caduca (~1 h en Google y
/// Microsoft) y los providers de arriba los guardan mientras viva el
/// proceso. En Android la app puede seguir abierta horas: sin esto, la
/// siguiente operación usaba un token vencido y la nube respondía
/// `invalid_token` (visto en el Redmi al adoptar una contraseña cambiada en
/// Windows). Toda operación contra la nube pasa por aquí.
Future<SyncPort?> freshActiveSyncPort(Ref ref) {
  ref.invalidate(syncPortForProvider);
  ref.invalidate(activeSyncPortProvider);
  return ref.read(activeSyncPortProvider.future);
}

/// Como [freshActiveSyncPort], para una nube concreta.
Future<SyncPort?> freshSyncPortFor(Ref ref, SyncProviderId provider) {
  ref.invalidate(syncPortForProvider(provider));
  return ref.read(syncPortForProvider(provider).future);
}

/// El puerto de una nube cualquiera, conectada en este dispositivo (`null`
/// si no lo está). Lo usa también la mudanza entre nubes (ADR 0023).
@Riverpod(keepAlive: true)
Future<SyncPort?> syncPortFor(Ref ref, SyncProviderId provider) async {
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

      if (usesDesktopGoogleAuth) {
        if (account.refreshToken == null) return null;
        final connection = await ref
            .watch(googleDriveDesktopAuthProvider)
            .reconnect(
              refreshToken: account.refreshToken!,
              email: account.email,
            );
        return GoogleDriveSyncAdapter(connection.httpClient);
      }

      final connection = await ref
          .watch(googleDriveAndroidAuthProvider)
          .reconnectSilently(email: account.email);
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
  }
}
