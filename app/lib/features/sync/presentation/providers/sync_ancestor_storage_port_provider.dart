// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Gabriel Ángel Montoya Rico

import 'package:lockspire/features/vault/domain/ports/vault_storage_port.dart';
import 'package:lockspire/features/vault/presentation/providers/vault_file_path_provider.dart';
import 'package:lockspire/features/vault/presentation/providers/vault_storage_factory_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'sync_ancestor_storage_port_provider.g.dart';

/// Composition root: [VaultStoragePort] apuntando al snapshot del último
/// archivo sincronizado con éxito (el "ancestro común" del merge de 3
/// vías, ver docs/adr/0006-modelo-resolucion-conflictos.md). Usa la misma
/// fábrica de almacenamiento que la bóveda, solo cambia la ruta; sync no
/// conoce el adaptador concreto (hallazgo A4).
@Riverpod(keepAlive: true)
Future<VaultStoragePort> syncAncestorStoragePort(Ref ref) async {
  final vaultPath = await ref.watch(vaultFilePathProvider.future);
  return ref.watch(vaultStorageFactoryProvider)('$vaultPath.sync-ancestor');
}
