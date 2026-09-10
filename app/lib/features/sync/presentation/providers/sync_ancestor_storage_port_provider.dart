// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Lockspire

import 'package:lockspire/features/vault/domain/ports/vault_storage_port.dart';
import 'package:lockspire/features/vault/infrastructure/atomic_file_vault_storage_adapter.dart';
import 'package:lockspire/features/vault/presentation/providers/vault_file_path_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'sync_ancestor_storage_port_provider.g.dart';

/// Composition root: [VaultStoragePort] apuntando al snapshot del último
/// archivo sincronizado con éxito (el "ancestro común" del merge de 3
/// vías, ver docs/adr/0006-modelo-resolucion-conflictos.md) — reusa
/// `AtomicFileVaultStorageAdapter` tal cual, solo cambia la ruta.
@Riverpod(keepAlive: true)
Future<VaultStoragePort> syncAncestorStoragePort(Ref ref) async {
  final vaultPath = await ref.watch(vaultFilePathProvider.future);
  return AtomicFileVaultStorageAdapter('$vaultPath.sync-ancestor');
}
