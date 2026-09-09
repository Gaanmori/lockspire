// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Lockspire

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../application/create_vault_use_case.dart';
import '../application/unlock_vault_use_case.dart';
import 'providers/crypto_port_provider.dart';
import 'providers/vault_storage_port_provider.dart';
import 'vault_session_state.dart';

part 'vault_session_controller.g.dart';

/// Único lugar que conecta los casos de uso de `application/` con los
/// adaptadores reales de `infrastructure/` (vía los providers de
/// composition root) — el resto de la UI solo habla con este controller.
@riverpod
class VaultSessionController extends _$VaultSessionController {
  @override
  Future<VaultSessionState> build() async {
    final storage = await ref.watch(vaultStoragePortProvider.future);
    final exists = await storage.exists();
    return exists ? const VaultSessionLocked() : const VaultSessionNoVault();
  }

  Future<void> createVault(String masterPassword) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final storage = await ref.read(vaultStoragePortProvider.future);
      final crypto = await ref.read(cryptoPortProvider.future);
      final vault = await CreateVaultUseCase(storage: storage, crypto: crypto)(
        masterPassword: masterPassword,
      );
      return VaultSessionUnlocked(vault);
    });
  }

  Future<void> unlock(String masterPassword) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final storage = await ref.read(vaultStoragePortProvider.future);
      final crypto = await ref.read(cryptoPortProvider.future);
      final vault = await UnlockVaultUseCase(storage: storage, crypto: crypto)(
        masterPassword: masterPassword,
      );
      return VaultSessionUnlocked(vault);
    });
  }

  void lock() {
    state = const AsyncData(VaultSessionLocked());
  }
}
