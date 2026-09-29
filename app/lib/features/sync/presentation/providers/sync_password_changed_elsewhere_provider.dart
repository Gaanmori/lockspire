// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Gabriel Ángel Montoya Rico

import 'package:lockspire/features/vault/application/password_changed_elsewhere_port.dart';
import 'package:lockspire/features/vault/presentation/providers/crypto_port_provider.dart';
import 'package:lockspire/features/vault/presentation/providers/vault_storage_port_provider.dart';
import 'package:lockspire/shared/platform_capabilities.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../domain/ports/active_sync_provider_port.dart';

import '../../application/sync_password_changed_elsewhere.dart';
import '../../infrastructure/google_drive_sync_adapter.dart';
import 'active_sync_port_provider.dart';
import 'google_drive_account_port_provider.dart';
import 'google_drive_android_auth_provider.dart';
import 'current_active_sync_provider_provider.dart';
import 'sync_ancestor_storage_port_provider.dart';
import 'sync_state_port_provider.dart';

part 'sync_password_changed_elsewhere_provider.g.dart';

/// Implementación de [PasswordChangedElsewherePort] sobre la sync (ADR
/// 0024). La app la conecta al puerto de `vault` en
/// `lib/app_composition.dart`.
@Riverpod(keepAlive: true)
Future<PasswordChangedElsewherePort> syncPasswordChangedElsewhere(
  Ref ref,
) async {
  return SyncPasswordChangedElsewhere(
    localStorage: await ref.watch(vaultStoragePortProvider.future),
    ancestorStorage: await ref.watch(syncAncestorStoragePortProvider.future),
    loadRemote: () => freshActiveSyncPort(ref),
    syncState: ref.watch(syncStatePortProvider),
    crypto: await ref.watch(cryptoPortProvider.future),
    loadRemoteForCheck: () async {
      final googleOnAndroid =
          ref.read(platformCapabilitiesProvider).isAndroid &&
          await ref.read(currentActiveSyncProviderProvider.future) ==
              SyncProviderId.googleDrive;
      if (!googleOnAndroid) return freshActiveSyncPort(ref);
      final account = await ref
          .read(googleDriveAccountPortProvider)
          .googleDriveAccount();
      if (account == null) return null;
      final connection = await ref
          .read(googleDriveAndroidAuthProvider)
          .authorizeWithoutUi(email: account.email);
      return connection == null
          ? null
          : GoogleDriveSyncAdapter(connection.httpClient);
    },
  );
}
