// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Gabriel Ángel Montoya Rico

import 'package:lockspire/features/vault/domain/ports/vault_storage_port.dart';

/// Puerto de sincronización con un proveedor remoto (ver
/// docs/adr/0006-modelo-resolucion-conflictos.md).
///
/// Cada proveedor (WebDAV, Drive, OneDrive, Dropbox...) es un adaptador
/// independiente en `infrastructure/` — añadir uno nuevo no toca dominio
/// ni casos de uso (ver CLAUDE.md).
///
/// Opera sobre [VaultFile] (el mismo tipo que usa `VaultStoragePort` para
/// el almacenamiento local) — mover la bóveda entre local y remoto no
/// necesita tocar claves ni contenido desencriptado, es un blob único
/// cifrado (ADR 0004).
abstract class SyncPort {
  Future<bool> remoteVaultExists();

  Future<VaultFile> downloadVault();

  Future<void> uploadVault(VaultFile file);
}
