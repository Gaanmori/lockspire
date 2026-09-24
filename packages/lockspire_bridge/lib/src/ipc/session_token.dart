// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Lockspire

import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'posix_ffi.dart' as posix;

/// Token de sesión del canal IPC: 32 bytes de `Random.secure()` en
/// base64url sin relleno (43 caracteres). Se regenera en cada arranque de
/// la app (ADR 0013).
String generateSessionToken() {
  final random = Random.secure();
  final bytes = List<int>.generate(32, (_) => random.nextInt(256));
  return base64Url.encode(bytes).replaceAll('=', '');
}

/// Escribe el token. En Linux el archivo se crea vacío, se restringe a
/// `0600` y solo entonces se escribe el contenido.
void writeSessionToken(String path, String token) {
  final file = File(path);
  if (file.existsSync()) file.deleteSync();
  file.createSync();
  if (Platform.isLinux) posix.chmod(path, 0x180); // 0600
  file.writeAsStringSync(token, flush: true);
}

String readSessionToken(String path) => File(path).readAsStringSync().trim();

/// Comparación en tiempo constante respecto al contenido (la longitud es
/// fija y pública).
bool tokensEqual(String a, String b) {
  final x = utf8.encode(a);
  final y = utf8.encode(b);
  if (x.length != y.length) return false;
  var diff = 0;
  for (var i = 0; i < x.length; i++) {
    diff |= x[i] ^ y[i];
  }
  return diff == 0;
}
