// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Gabriel Ángel Montoya Rico

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../domain/ports/active_sync_provider_port.dart';
import 'active_sync_provider_port_provider.dart';
import 'current_google_drive_account_provider.dart';
import 'current_one_drive_account_provider.dart';
import 'current_sync_credentials_provider.dart';

part 'is_sync_configured_provider.g.dart';

/// Agnóstico de proveedor: `true` si hay algo configurado (WebDAV o
/// Google Drive), sin importar cuál. `VaultSessionController` lo usa
/// para decidir si dispara sync automática — no necesita saber que
/// existen `WebDavCredentials`/`GoogleDriveAccount`, solo si hay algo.
@Riverpod(keepAlive: true)
Future<bool> isSyncConfigured(Ref ref) async {
  final provider = await ref
      .watch(activeSyncProviderPortProvider)
      .activeProvider();
  return switch (provider) {
    SyncProviderId.webdav =>
      (await ref.watch(currentSyncCredentialsProvider.future)) != null,
    SyncProviderId.googleDrive =>
      (await ref.watch(currentGoogleDriveAccountProvider.future)) != null,
    SyncProviderId.oneDrive =>
      (await ref.watch(currentOneDriveAccountProvider.future)) != null,
    null => false,
  };
}
