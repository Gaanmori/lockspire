// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Gabriel Ángel Montoya Rico

import 'dart:io';

import 'package:lockspire_bridge/lockspire_bridge.dart';
import 'package:lockspire_native_host/native_host.dart';
import 'package:path/path.dart' as p;

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
    _log('arranque: $e');
    exitCode = 70;
    return;
  }

  await runNativeHost(
    input: stdin,
    output: (frame) => stdout.add(frame),
    app: IpcAppLink(location: location, caller: caller),
    log: _log,
  );
  await stdout.flush();
}

/// Errores del canal a stderr (Chrome lo muestra si se lanza con
/// `--enable-logging`) y a un log local. Nunca el contenido de los
/// mensajes: solo el tipo de petición y el motivo técnico.
void _log(String message) {
  final line = '${DateTime.now().toIso8601String()} $message';
  stderr.writeln('lockspire-native-host: $line');
  try {
    final base = Platform.isWindows
        ? Platform.environment['LOCALAPPDATA']
        : Platform.environment['XDG_STATE_HOME'] ??
              p.join(Platform.environment['HOME'] ?? '', '.local', 'state');
    if (base == null || base.isEmpty) return;
    final file = File(p.join(base, 'Lockspire', 'logs', 'native-host.log'));
    file.parent.createSync(recursive: true);
    // Tope simple: si pasa de 256 KiB se empieza de cero.
    if (file.existsSync() && file.lengthSync() > 256 * 1024) {
      file.writeAsStringSync('');
    }
    file.writeAsStringSync('$line\n', mode: FileMode.append, flush: true);
  } catch (_) {
    // El log nunca debe tumbar al host.
  }
}
