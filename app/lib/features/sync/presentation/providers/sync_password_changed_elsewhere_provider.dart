// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Lockspire

import 'package:lockspire/features/vault/application/password_changed_elsewhere_port.dart';
import 'package:lockspire/features/vault/presentation/providers/crypto_port_provider.dart';
import 'package:lockspire/features/vault/presentation/providers/vault_storage_port_provider.dart';
import 'package:lockspire/shared/platform_capabilities.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../domain/ports/active_sync_provider_port.dart';

import '../../application/sync_password_changed_elsewhere.dart';
import 'active_sync_port_provider.dart';
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
    loadRemote: () => ref.read(activeSyncPortProvider.future),
    syncState: ref.watch(syncStatePortProvider),
    crypto: await ref.watch(cryptoPortProvider.future),
    remoteCheckAllowed:
        !(ref.watch(platformCapabilitiesProvider).isAndroid &&
            await ref.watch(currentActiveSyncProviderProvider.future) ==
                SyncProviderId.googleDrive),
  );
}
