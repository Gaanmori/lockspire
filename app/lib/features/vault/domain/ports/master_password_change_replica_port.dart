// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Gabriel Ángel Montoya Rico

import 'dart:typed_data';

import 'vault_storage_port.dart';

/// Las copias de la bóveda fuera de este dispositivo (la sync), vistas
/// desde el cambio de contraseña maestra — ver
/// docs/adr/0018-cambio-de-contrasena-maestra.md. Sin sync configurada, el
/// adaptador no hace nada.
abstract class MasterPasswordChangeReplicaPort {
  /// Sincroniza con la clave **actual** para que local, remoto y ancestro
  /// queden iguales antes de recifrar. Lanza si no se puede: en ese caso
  /// no se cambia la contraseña.
  Future<void> syncBeforeChange({
    required Uint8List key,
    required VaultHeader header,
  });

  /// Publica el archivo ya recifrado con la clave nueva y lo marca como
  /// sincronizado. Lanza si no se pudo: en ese caso no se escribe nada
  /// local.
  Future<void> publish(VaultFile rekeyed);
}
