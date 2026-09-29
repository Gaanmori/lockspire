// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Gabriel Ángel Montoya Rico

import 'package:lockspire/shared/secure_storage_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../domain/ports/sync_credentials_port.dart';

import '../../infrastructure/secure_storage_sync_credentials_adapter.dart';

part 'sync_credentials_port_provider.g.dart';

@Riverpod(keepAlive: true)
SyncCredentialsPort syncCredentialsPort(Ref ref) {
  return SecureStorageSyncCredentialsAdapter(ref.watch(secureStorageProvider));
}
