// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Lockspire

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../application/change_master_password_use_case.dart';
import 'crypto_port_provider.dart';
import 'master_password_change_replica_port_provider.dart';
import 'vault_storage_port_provider.dart';

part 'change_master_password_use_case_provider.g.dart';

/// Composition root de [ChangeMasterPasswordUseCase] (ADR 0018). Inyectado en vez de construirse dentro del controller (revisión
/// 2026-09-25, hallazgo A5): los tests lo reemplazan igual que a los
/// puertos.
@Riverpod(keepAlive: true)
Future<ChangeMasterPasswordUseCase> changeMasterPasswordUseCase(
  Ref ref,
) async => ChangeMasterPasswordUseCase(
  storage: await ref.watch(vaultStoragePortProvider.future),
  crypto: await ref.watch(cryptoPortProvider.future),
  replica: await ref.watch(masterPasswordChangeReplicaPortProvider.future),
);
