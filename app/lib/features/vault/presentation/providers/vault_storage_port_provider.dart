// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Lockspire

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../domain/ports/vault_storage_port.dart';
import 'vault_file_path_provider.dart';
import 'vault_storage_factory_provider.dart';

part 'vault_storage_port_provider.g.dart';

/// Composition root: inyecta el adaptador real de [VaultStoragePort] (ver
/// ADR 0003 — Riverpod actúa como composition root).
@Riverpod(keepAlive: true)
Future<VaultStoragePort> vaultStoragePort(Ref ref) async {
  final path = await ref.watch(vaultFilePathProvider.future);
  return ref.watch(vaultStorageFactoryProvider)(path);
}
