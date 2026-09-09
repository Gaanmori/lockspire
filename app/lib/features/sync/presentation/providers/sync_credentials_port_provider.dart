// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Lockspire

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../domain/ports/sync_credentials_port.dart';
import 'secure_storage_sync_settings_adapter_provider.dart';

part 'sync_credentials_port_provider.g.dart';

@Riverpod(keepAlive: true)
SyncCredentialsPort syncCredentialsPort(Ref ref) {
  return ref.watch(secureStorageSyncSettingsAdapterProvider);
}
