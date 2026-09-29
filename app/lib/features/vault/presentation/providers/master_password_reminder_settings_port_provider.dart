// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Gabriel Ángel Montoya Rico

import 'package:lockspire/shared/secure_storage_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../domain/ports/master_password_reminder_settings_port.dart';
import '../../infrastructure/secure_storage_master_password_reminder_adapter.dart';

part 'master_password_reminder_settings_port_provider.g.dart';

/// Composition root del ajuste de días de ADR 0017.
@Riverpod(keepAlive: true)
MasterPasswordReminderSettingsPort masterPasswordReminderSettingsPort(
  Ref ref,
) => SecureStorageMasterPasswordReminderAdapter(
  ref.watch(secureStorageProvider),
);
