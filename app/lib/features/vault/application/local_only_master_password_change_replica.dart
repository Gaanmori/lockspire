// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Gabriel Ángel Montoya Rico

import 'dart:typed_data';

import '../domain/ports/master_password_change_replica_port.dart';
import '../domain/ports/vault_storage_port.dart';

/// [MasterPasswordChangeReplicaPort] sin copias fuera del dispositivo: el
/// cambio de contraseña es solo local. Es el valor por defecto de `vault`;
/// la app lo reemplaza por la implementación de `sync` (ver
/// `lib/app_composition.dart`, hallazgo A3).
class LocalOnlyMasterPasswordChangeReplica
    implements MasterPasswordChangeReplicaPort {
  const LocalOnlyMasterPasswordChangeReplica();

  @override
  Future<void> syncBeforeChange({
    required Uint8List key,
    required VaultHeader header,
  }) async {}

  @override
  Future<void> publish(VaultFile rekeyed) async {}
}
