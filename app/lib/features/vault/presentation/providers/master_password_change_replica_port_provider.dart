// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Gabriel Ángel Montoya Rico

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../application/local_only_master_password_change_replica.dart';
import '../../domain/ports/master_password_change_replica_port.dart';

part 'master_password_change_replica_port_provider.g.dart';

/// Réplicas de la bóveda para el cambio de contraseña (ADR 0018). `vault` no
/// conoce la sync: por defecto no replica nada, y la app sobreescribe este
/// provider con la implementación de `sync` en `lib/app_composition.dart`
/// (hallazgo A3). Un test verifica que esa conexión exista, porque sin ella
/// cambiar la contraseña dejaría de sincronizar en silencio.
@Riverpod(keepAlive: true)
Future<MasterPasswordChangeReplicaPort> masterPasswordChangeReplicaPort(
  Ref ref,
) async => const LocalOnlyMasterPasswordChangeReplica();
