// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Gabriel Ángel Montoya Rico

import 'package:lockspire/features/vault/domain/ports/vault_storage_port.dart';
import 'package:lockspire/features/vault/presentation/providers/unlock_vault_use_case_provider.dart';
import 'package:lockspire/features/vault/presentation/providers/vault_auth_attempt_provider.dart';
import 'package:lockspire/features/vault/presentation/providers/vault_storage_port_provider.dart';
import 'package:lockspire/features/vault/presentation/vault_session_controller.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../application/restore_vault_from_remote_use_case.dart';
import 'providers/sync_ancestor_storage_port_provider.dart';
import 'providers/sync_state_port_provider.dart';

part 'restore_vault_controller.g.dart';

@Riverpod(keepAlive: true)
RestoreVaultController restoreVaultController(Ref ref) =>
    RestoreVaultController(ref);

/// Restaurar la bóveda desde la nube (`RestoreVaultScreen`, hallazgo A3).
/// El progreso y el error del intento se reflejan en
/// `vaultAuthAttemptProvider`, igual que al crear o desbloquear.
class RestoreVaultController {
  final Ref _ref;

  RestoreVaultController(this._ref);

  Future<void> restore({
    required VaultFile file,
    required String masterPassword,
  }) async {
    final attempt = _ref.read(vaultAuthAttemptProvider.notifier);
    attempt.state = const AsyncLoading();
    try {
      final unlocked = await RestoreVaultFromRemoteUseCase(
        unlock: await _ref.read(unlockVaultUseCaseProvider.future),
        localStorage: await _ref.read(vaultStoragePortProvider.future),
        ancestorStorage: await _ref.read(
          syncAncestorStoragePortProvider.future,
        ),
        syncState: _ref.read(syncStatePortProvider),
      ).call(file: file, masterPassword: masterPassword);
      await _ref
          .read(vaultSessionControllerProvider.notifier)
          .openRestoredSession(unlocked);
      attempt.state = const AsyncData(null);
    } catch (error, stackTrace) {
      attempt.state = AsyncError(error, stackTrace);
    }
  }
}
