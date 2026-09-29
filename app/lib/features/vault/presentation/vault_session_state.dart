// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Gabriel Ángel Montoya Rico

import 'dart:typed_data';

import '../domain/entities/vault.dart';
import '../domain/ports/vault_storage_port.dart';

/// Estado de la sesión de bóveda en la UI.
///
/// Los estados de carga/error de las operaciones (crear, desbloquear) los
/// maneja el `AsyncValue` del propio [VaultSessionController] — no se
/// duplican aquí.
sealed class VaultSessionState {
  const VaultSessionState();
}

/// No existe todavía un archivo de bóveda — hay que crear uno.
class VaultSessionNoVault extends VaultSessionState {
  const VaultSessionNoVault();
}

/// Existe un archivo de bóveda pero no está desbloqueada.
class VaultSessionLocked extends VaultSessionState {
  const VaultSessionLocked();
}

/// La bóveda está desbloqueada; [vault] es su contenido desencriptado.
///
/// También retiene la clave derivada ([key]) y el [header]/[fileHash]
/// vigentes — necesarios para guardar cambios (agregar/editar/borrar
/// entradas) sin volver a pedir la contraseña maestra ni re-derivar vía
/// Argon2id en cada guardado (ver docs/STATE.md — Fase 5).
///
/// [key] es el secreto más sensible del sistema una vez desbloqueada la
/// bóveda. Deliberadamente **no** se agrega ningún override de
/// `toString()`/`==`/`hashCode` en esta clase — el `toString()` por
/// defecto de Dart solo expone el nombre de la clase, no sus campos. No
/// agregar uno "por prolijidad" sin pensar en esto: filtraría la clave a
/// cualquier log/print/devtools que serialice el estado.
class VaultSessionUnlocked extends VaultSessionState {
  final Vault vault;
  final Uint8List key;
  final VaultHeader header;
  final String fileHash;

  const VaultSessionUnlocked({
    required this.vault,
    required this.key,
    required this.header,
    required this.fileHash,
  });

  VaultSessionUnlocked copyWith({Vault? vault, String? fileHash}) {
    return VaultSessionUnlocked(
      vault: vault ?? this.vault,
      key: key,
      header: header,
      fileHash: fileHash ?? this.fileHash,
    );
  }
}
