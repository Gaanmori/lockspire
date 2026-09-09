// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Lockspire

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../infrastructure/secure_storage_sync_settings_adapter.dart';

part 'secure_storage_sync_settings_adapter_provider.g.dart';

/// Instancia compartida del adaptador (implementa tanto
/// [SyncCredentialsPort] como [SyncStatePort] sobre el mismo storage) —
/// ver `sync_credentials_port_provider.dart` y `sync_state_port_provider.dart`.
@Riverpod(keepAlive: true)
SecureStorageSyncSettingsAdapter secureStorageSyncSettingsAdapter(Ref ref) {
  return const SecureStorageSyncSettingsAdapter(FlutterSecureStorage());
}
