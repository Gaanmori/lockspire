// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Gabriel Ángel Montoya Rico

import 'package:lockspire/shared/secure_storage_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../domain/ports/active_sync_provider_port.dart';

import '../../infrastructure/secure_storage_active_sync_provider_adapter.dart';

part 'active_sync_provider_port_provider.g.dart';

@Riverpod(keepAlive: true)
ActiveSyncProviderPort activeSyncProviderPort(Ref ref) {
  return SecureStorageActiveSyncProviderAdapter(
    ref.watch(secureStorageProvider),
  );
}
