// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Lockspire

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../domain/ports/active_sync_provider_port.dart';
import 'active_sync_provider_port_provider.dart';

part 'current_active_sync_provider_provider.g.dart';

/// Cuál proveedor está activo actualmente (o `null` si ninguno) — la UI
/// lo usa para saber qué selector mostrar marcado al entrar a
/// `SyncSettingsScreen`.
@Riverpod(keepAlive: true)
Future<SyncProviderId?> currentActiveSyncProvider(Ref ref) {
  return ref.watch(activeSyncProviderPortProvider).activeProvider();
}
