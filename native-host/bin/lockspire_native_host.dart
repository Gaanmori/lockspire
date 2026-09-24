// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Lockspire

import 'dart:io';

import 'package:lockspire_bridge/lockspire_bridge.dart';
import 'package:lockspire_native_host/native_host.dart';

/// Punto de entrada del native host. Lo lanza el navegador (una vez por
/// conexión) según el manifest `com.lockspire.native_host.json`.
Future<void> main(List<String> args) async {
  final caller = callerFromArgs(args);
  if (caller == null) {
    stderr.writeln(
      'lockspire-native-host: este programa lo lanza el navegador, '
      'no se ejecuta a mano.',
    );
    exitCode = 64;
    return;
  }

  final IpcLocation location;
  try {
    location = IpcLocation.forCurrentUser();
  } catch (e) {
    stderr.writeln('lockspire-native-host: $e');
    exitCode = 70;
    return;
  }

  await runNativeHost(
    input: stdin,
    output: (frame) => stdout.add(frame),
    app: IpcAppLink(location: location, caller: caller),
  );
  await stdout.flush();
}
