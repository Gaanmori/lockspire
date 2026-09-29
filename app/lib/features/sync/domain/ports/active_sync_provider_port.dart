// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Gabriel Ángel Montoya Rico

/// Proveedores de sync soportados. Uno solo puede estar activo a la vez —
/// no hay caso de uso para tener credenciales de dos proveedores en
/// simultáneo (ver Fase 8 en docs/STATE.md).
enum SyncProviderId { webdav, googleDrive, oneDrive }

/// Puerto que guarda cuál proveedor de sync está activo actualmente.
///
/// Separado de [SyncCredentialsPort]/`GoogleDriveAccountPort` a propósito:
/// cada proveedor guarda sus propias credenciales bajo su propio puerto,
/// pero solo uno de ellos es el que `activeSyncPortProvider` usa para
/// construir el `SyncPort` real.
abstract class ActiveSyncProviderPort {
  Future<SyncProviderId?> activeProvider();

  Future<void> saveActiveProvider(SyncProviderId id);

  Future<void> clearActiveProvider();
}
