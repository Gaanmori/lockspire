// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Gabriel Ángel Montoya Rico

import 'package:lockspire/shared/secure_storage_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../domain/ports/google_drive_account_port.dart';

import '../../infrastructure/secure_storage_google_drive_account_adapter.dart';

part 'google_drive_account_port_provider.g.dart';

@Riverpod(keepAlive: true)
GoogleDriveAccountPort googleDriveAccountPort(Ref ref) {
  return SecureStorageGoogleDriveAccountAdapter(
    ref.watch(secureStorageProvider),
  );
}
