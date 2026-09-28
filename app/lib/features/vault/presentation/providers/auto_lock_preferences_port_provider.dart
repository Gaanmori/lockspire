// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Lockspire

import 'package:lockspire/shared/secure_storage_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../domain/ports/auto_lock_preferences_port.dart';
import '../../infrastructure/secure_storage_auto_lock_adapter.dart';

part 'auto_lock_preferences_port_provider.g.dart';

/// Composition root del almacenamiento del tiempo de bloqueo (ADR 0016).
@Riverpod(keepAlive: true)
AutoLockPreferencesPort autoLockPreferencesPort(Ref ref) =>
    SecureStorageAutoLockAdapter(ref.watch(secureStorageProvider));
