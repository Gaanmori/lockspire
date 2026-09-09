// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Lockspire

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../domain/ports/sync_port.dart';
import '../../infrastructure/webdav_sync_adapter.dart';
import 'current_sync_credentials_provider.dart';

part 'webdav_sync_port_provider.g.dart';

/// `null` si sync todavía no está configurado (no hay credenciales
/// guardadas).
@Riverpod(keepAlive: true)
Future<SyncPort?> webdavSyncPort(Ref ref) async {
  final credentials = await ref.watch(currentSyncCredentialsProvider.future);
  if (credentials == null) return null;
  return WebdavSyncAdapter(credentials);
}
