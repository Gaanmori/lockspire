// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Gabriel Ángel Montoya Rico

import 'package:lockspire/features/sync/domain/ports/sync_state_port.dart';
import 'package:lockspire/features/vault/application/unlock_vault_use_case.dart';
import 'package:lockspire/features/vault/application/unlocked_vault_result.dart';
import 'package:lockspire/features/vault/domain/ports/vault_storage_port.dart';

/// Restaura en un dispositivo sin bóveda local una bóveda descargada de la
/// nube (Fase 9). Vive en `sync` porque siembra el estado de la sync
/// (revisión 2026-09-25, hallazgo A3: antes lo hacía `vault`).
///
/// Primero descifra [call]`.file` con la contraseña: si no es correcta,
/// lanza y **no escribe nada**. Si lo es, el archivo pasa a ser la bóveda
/// local **y** el ancestro y el hash de la última sync. Esto no es opcional:
/// sin eso, la primera sync vería un cambio local falso (nada cambió, se
/// acaba de traer tal cual) y haría un merge innecesario en vez de
/// `SyncUpToDate`.
class RestoreVaultFromRemoteUseCase {
  final UnlockVaultUseCase unlock;
  final VaultStoragePort localStorage;
  final VaultStoragePort ancestorStorage;
  final SyncStatePort syncState;

  const RestoreVaultFromRemoteUseCase({
    required this.unlock,
    required this.localStorage,
    required this.ancestorStorage,
    required this.syncState,
  });

  Future<UnlockedVaultResult> call({
    required VaultFile file,
    required String masterPassword,
  }) async {
    final unlocked = await unlock.unlockFile(
      file: file,
      masterPassword: masterPassword,
    );
    await localStorage.write(file);
    await ancestorStorage.write(file);
    await syncState.saveLastSyncedHash(unlocked.fileHash);
    return unlocked;
  }
}
