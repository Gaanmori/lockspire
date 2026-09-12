// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Lockspire

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../domain/ports/one_drive_account_port.dart';
import 'one_drive_account_port_provider.dart';

part 'current_one_drive_account_provider.g.dart';

/// Cuenta de Microsoft conectada actualmente (o `null` si no hay ninguna)
/// — la UI lo usa para decidir qué mostrar, igual que
/// `current_google_drive_account_provider.dart`.
@Riverpod(keepAlive: true)
Future<OneDriveAccount?> currentOneDriveAccount(Ref ref) {
  return ref.watch(oneDriveAccountPortProvider).oneDriveAccount();
}
