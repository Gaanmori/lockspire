// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Gabriel Ángel Montoya Rico

import 'package:flutter_riverpod/misc.dart' show Override;

import 'features/sync/presentation/providers/sync_master_password_change_replica_provider.dart';
import 'features/sync/presentation/providers/sync_password_changed_elsewhere_provider.dart';
import 'features/vault/presentation/providers/master_password_change_replica_port_provider.dart';
import 'features/vault/presentation/providers/password_changed_elsewhere_port_provider.dart';

/// Conexiones entre features que la app hace en su composition root, para
/// que ninguna feature dependa de otra (revisión 2026-09-25, hallazgo A3).
/// Las usa `main.dart`; `test/app_composition_test.dart` verifica que estén.
List<Override> appOverrides() => [
  // Cambiar la contraseña maestra sincroniza antes y publica después (ADR
  // 0018): `vault` define el puerto y `sync` lo implementa.
  masterPasswordChangeReplicaPortProvider.overrideWith(
    (ref) => ref.watch(syncMasterPasswordChangeReplicaProvider.future),
  ),
  // Si la contraseña se cambió en otro dispositivo, al abrir se pide la
  // nueva, sin biometría (ADR 0024).
  passwordChangedElsewherePortProvider.overrideWith(
    (ref) => ref.watch(syncPasswordChangedElsewhereProvider.future),
  ),
];
