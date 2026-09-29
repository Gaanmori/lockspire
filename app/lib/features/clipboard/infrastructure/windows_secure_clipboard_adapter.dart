// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Gabriel Ángel Montoya Rico

import 'package:flutter/services.dart';

import '../domain/ports/secure_clipboard_port.dart';

/// Windows: el runner C++ (`windows/runner/secure_clipboard.cpp`) copia con
/// los formatos `ExcludeClipboardContentFromMonitorProcessing`,
/// `CanIncludeInClipboardHistory = 0` y `CanUploadToCloudClipboard = 0`, y
/// devuelve el número de secuencia del portapapeles. Borrar solo si la
/// secuencia no cambió evita pisar algo que el usuario copió después, sin
/// tener que leer el portapapeles.
class WindowsSecureClipboardAdapter implements SecureClipboardPort {
  final MethodChannel _channel;
  int? _sequence;

  WindowsSecureClipboardAdapter({MethodChannel? channel})
    : _channel =
          channel ?? const MethodChannel('com.lockspire.lockspire/clipboard');

  @override
  Future<void> copySensitive(
    String text, {
    required Duration clearAfter,
  }) async {
    // En escritorio la app no se congela: alcanza con ClipboardGuard.
    _sequence = await _channel.invokeMethod<int>('copySensitive', text);
  }

  @override
  Future<void> clearIfStillOurs() async {
    final sequence = _sequence;
    if (sequence == null) return;
    _sequence = null;
    await _channel.invokeMethod<bool>('clearIfUnchanged', sequence);
  }
}
