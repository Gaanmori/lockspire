// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Lockspire

import 'dart:async';
import 'dart:isolate';

import 'package:lockspire_bridge/lockspire_bridge.dart';

/// Pide a la instancia de Lockspire que ya está en ejecución que muestre
/// su ventana (instancia única, ADR 0012/0013). `true` si respondió.
///
/// Corre en otro isolate: en Windows el cliente IPC hace llamadas
/// bloqueantes, y con un timeout para que un servidor colgado (o un
/// endpoint que no es de confianza) no deje la app sin arrancar.
Future<bool> signalExistingInstance() async {
  try {
    return await Isolate.run(_signal).timeout(const Duration(seconds: 3));
  } catch (_) {
    return false;
  }
}

Future<bool> _signal() async {
  final client = await BridgeClient.connect(
    location: IpcLocation.forCurrentUser(),
    client: ClientKind.appInstance,
  );
  try {
    final response = await client.request(const ShowAppRequest('show'));
    return response['type'] == MessageType.ok;
  } finally {
    await client.close();
  }
}
