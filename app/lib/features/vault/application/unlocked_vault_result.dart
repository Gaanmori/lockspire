// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Lockspire

import 'dart:typed_data';

import '../domain/entities/vault.dart';
import '../domain/ports/vault_storage_port.dart';

/// Resultado compartido de `CreateVaultUseCase`/`UnlockVaultUseCase`: no
/// solo el [Vault] desencriptado, también la clave derivada y el header
/// vigente — la sesión los retiene mientras la bóveda está desbloqueada
/// (ver docs/STATE.md — Fase 5) para poder guardar cambios sin volver a
/// pedir la contraseña maestra ni re-derivar vía Argon2id en cada guardado.
///
/// [key] es el secreto más sensible del sistema una vez desbloqueada la
/// bóveda — quien retenga este resultado (ver `VaultSessionUnlocked`) no
/// debe loguearlo ni incluirlo en ningún `toString()`/serialización.
class UnlockedVaultResult {
  final Vault vault;
  final Uint8List key;
  final VaultHeader header;
  final String fileHash;

  const UnlockedVaultResult({
    required this.vault,
    required this.key,
    required this.header,
    required this.fileHash,
  });
}
