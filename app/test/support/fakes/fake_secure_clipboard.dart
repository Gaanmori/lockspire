// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Gabriel Ángel Montoya Rico

import 'package:lockspire/features/clipboard/domain/ports/secure_clipboard_port.dart';

/// Portapapeles en memoria: registra qué se copió, con qué plazo, y cuántas
/// veces se pidió limpiarlo. [failClear] simula un portapapeles que no
/// responde al limpiar.
class FakeSecureClipboard implements SecureClipboardPort {
  final copies = <String>[];
  final delays = <Duration>[];
  int clears = 0;
  bool failClear = false;

  @override
  Future<void> copySensitive(
    String text, {
    required Duration clearAfter,
  }) async {
    copies.add(text);
    delays.add(clearAfter);
  }

  @override
  Future<void> clearIfStillOurs() async {
    clears++;
    if (failClear) throw StateError('sin portapapeles');
  }
}
