// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Gabriel Ángel Montoya Rico

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../domain/ports/vault_storage_port.dart';
import '../../infrastructure/atomic_file_vault_storage_adapter.dart';

part 'vault_storage_factory_provider.g.dart';

/// Composition root de [VaultStorageFactory]: el único lugar que sabe que
/// los archivos de bóveda se escriben con [AtomicFileVaultStorageAdapter]
/// (hallazgo A4).
@Riverpod(keepAlive: true)
VaultStorageFactory vaultStorageFactory(Ref ref) =>
    AtomicFileVaultStorageAdapter.new;
