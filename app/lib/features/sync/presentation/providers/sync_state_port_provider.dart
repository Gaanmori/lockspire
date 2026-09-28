// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Lockspire

import 'package:lockspire/shared/secure_storage_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../domain/ports/sync_state_port.dart';

import '../../infrastructure/secure_storage_sync_state_adapter.dart';

part 'sync_state_port_provider.g.dart';

@Riverpod(keepAlive: true)
SyncStatePort syncStatePort(Ref ref) {
  return SecureStorageSyncStateAdapter(ref.watch(secureStorageProvider));
}
