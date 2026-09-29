// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Gabriel Ángel Montoya Rico

import 'package:lockspire/shared/secure_storage_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../domain/ports/password_unlock_history_port.dart';
import '../../infrastructure/secure_storage_password_unlock_history_adapter.dart';

part 'password_unlock_history_port_provider.g.dart';

/// Composition root del registro de desbloqueos con contraseña (ADR 0017).
@Riverpod(keepAlive: true)
PasswordUnlockHistoryPort passwordUnlockHistoryPort(Ref ref) =>
    SecureStoragePasswordUnlockHistoryAdapter(ref.watch(secureStorageProvider));
