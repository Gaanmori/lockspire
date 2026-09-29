// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Gabriel Ángel Montoya Rico

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../application/save_vault_use_case.dart';
import 'crypto_port_provider.dart';
import 'vault_storage_port_provider.dart';

part 'save_vault_use_case_provider.g.dart';

/// Composition root de [SaveVaultUseCase]. Inyectado en vez de construirse dentro del controller (revisión
/// 2026-09-25, hallazgo A5): los tests lo reemplazan igual que a los
/// puertos.
@Riverpod(keepAlive: true)
Future<SaveVaultUseCase> saveVaultUseCase(Ref ref) async => SaveVaultUseCase(
  storage: await ref.watch(vaultStoragePortProvider.future),
  crypto: await ref.watch(cryptoPortProvider.future),
);
