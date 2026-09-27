// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Lockspire

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../application/unlock_vault_use_case.dart';
import 'crypto_port_provider.dart';
import 'vault_storage_port_provider.dart';

part 'unlock_vault_use_case_provider.g.dart';

/// Composition root de [UnlockVaultUseCase]. Inyectado en vez de construirse dentro del controller (revisión
/// 2026-09-25, hallazgo A5): los tests lo reemplazan igual que a los
/// puertos.
@Riverpod(keepAlive: true)
Future<UnlockVaultUseCase> unlockVaultUseCase(Ref ref) async =>
    UnlockVaultUseCase(
      storage: await ref.watch(vaultStoragePortProvider.future),
      crypto: await ref.watch(cryptoPortProvider.future),
    );
