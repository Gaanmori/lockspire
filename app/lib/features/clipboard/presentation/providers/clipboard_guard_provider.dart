// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Gabriel Ángel Montoya Rico

import 'dart:io' show Platform;

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../application/clipboard_guard.dart';
import '../../domain/ports/secure_clipboard_port.dart';
import '../../infrastructure/android_secure_clipboard_adapter.dart';
import '../../infrastructure/flutter_secure_clipboard_adapter.dart';
import '../../infrastructure/windows_secure_clipboard_adapter.dart';

part 'clipboard_guard_provider.g.dart';

/// Composition root de [SecureClipboardPort] según la plataforma.
@Riverpod(keepAlive: true)
SecureClipboardPort secureClipboardPort(Ref ref) {
  if (Platform.isWindows) return WindowsSecureClipboardAdapter();
  if (Platform.isAndroid) return AndroidSecureClipboardAdapter();
  return FlutterSecureClipboardAdapter();
}

/// Uno solo por proceso: el bloqueo y la salida tienen que ver lo que se
/// copió desde cualquier pantalla.
@Riverpod(keepAlive: true)
ClipboardGuard clipboardGuard(Ref ref) {
  final guard = ClipboardGuard(port: ref.watch(secureClipboardPortProvider));
  ref.onDispose(guard.clearNow);
  return guard;
}
