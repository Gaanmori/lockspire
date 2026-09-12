// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Lockspire

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../domain/ports/one_drive_account_port.dart';
import 'secure_storage_sync_settings_adapter_provider.dart';

part 'one_drive_account_port_provider.g.dart';

@Riverpod(keepAlive: true)
OneDriveAccountPort oneDriveAccountPort(Ref ref) {
  return ref.watch(secureStorageSyncSettingsAdapterProvider);
}
