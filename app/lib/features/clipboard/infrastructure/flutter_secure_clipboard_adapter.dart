// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Gabriel Ángel Montoya Rico

import 'package:flutter/services.dart';

import '../domain/ports/secure_clipboard_port.dart';

/// Resto de plataformas (Linux): el portapapeles estándar de Flutter, sin
/// marca de sensible — no hay una convención común a todos los
/// escritorios. Sí se borra a tiempo, comparando el contenido.
class FlutterSecureClipboardAdapter implements SecureClipboardPort {
  String? _copied;

  @override
  Future<void> copySensitive(
    String text, {
    required Duration clearAfter,
  }) async {
    // En escritorio la app no se congela: alcanza con ClipboardGuard.
    await Clipboard.setData(ClipboardData(text: text));
    _copied = text;
  }

  @override
  Future<void> clearIfStillOurs() async {
    final copied = _copied;
    if (copied == null) return;
    _copied = null;
    final current = await Clipboard.getData(Clipboard.kTextPlain);
    if (current?.text == copied) {
      await Clipboard.setData(const ClipboardData(text: ''));
    }
  }
}
