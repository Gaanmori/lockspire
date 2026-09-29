// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Gabriel Ángel Montoya Rico

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../domain/ports/google_drive_account_port.dart';
import 'google_drive_account_port_provider.dart';

part 'current_google_drive_account_provider.g.dart';

/// Cuenta de Google conectada actualmente (o `null` si no hay ninguna) —
/// la UI lo usa para decidir qué mostrar, igual que
/// `current_sync_credentials_provider.dart` para WebDAV.
@Riverpod(keepAlive: true)
Future<GoogleDriveAccount?> currentGoogleDriveAccount(Ref ref) {
  return ref.watch(googleDriveAccountPortProvider).googleDriveAccount();
}
