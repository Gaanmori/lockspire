// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Lockspire

/// Puerto del estado local de sincronización.
///
/// Esta primera pasada de sync (ver docs/STATE.md) guarda solo el hash del
/// último archivo sincronizado con éxito — suficiente para detectar si
/// cambió un solo lado (local o remoto) desde la última sync, o si
/// cambiaron los dos (conflicto real). El snapshot desencriptado completo
/// que pide el merge automático por entrada de
/// docs/adr/0006-modelo-resolucion-conflictos.md es una pasada futura.
abstract class SyncStatePort {
  Future<String?> lastSyncedHash();

  Future<void> saveLastSyncedHash(String hash);
}
