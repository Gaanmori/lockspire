// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Gabriel Ángel Montoya Rico

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../domain/ports/sync_credentials_port.dart';
import 'sync_credentials_port_provider.dart';

part 'current_sync_credentials_provider.g.dart';

/// Credenciales guardadas actualmente (o `null` si sync no está
/// configurado todavía) — la UI lo usa para decidir qué mostrar.
@Riverpod(keepAlive: true)
Future<WebDavCredentials?> currentSyncCredentials(Ref ref) {
  return ref.watch(syncCredentialsPortProvider).read();
}
