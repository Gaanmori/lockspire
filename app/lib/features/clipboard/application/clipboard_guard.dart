// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Gabriel Ángel Montoya Rico

import 'dart:async';

import '../domain/ports/secure_clipboard_port.dart';

/// Tiempo que un secreto copiado queda en el portapapeles.
const defaultClipboardClearAfter = Duration(seconds: 30);

/// Copia secretos y garantiza que se borren: a los [clearAfter] o antes,
/// con [clearNow] (al bloquear la bóveda o al salir de la app). Cada copia
/// nueva reinicia el plazo, para no borrar antes de tiempo lo último que
/// se copió.
class ClipboardGuard {
  final SecureClipboardPort port;
  final Duration clearAfter;

  Timer? _timer;
  bool _pending = false;
  bool _retryOnResume = false;
  Future<void>? _clearing;

  ClipboardGuard({
    required this.port,
    this.clearAfter = defaultClipboardClearAfter,
  });

  Future<void> copy(String text) async {
    if (text.isEmpty) return;
    _timer?.cancel();
    await port.copySensitive(text, clearAfter: clearAfter);
    _pending = true;
    _retryOnResume = false;
    _timer = Timer(clearAfter, () {
      // Si venció con la app en segundo plano, algunos sistemas (HyperOS)
      // descartan el borrado en silencio: se repite al volver.
      _retryOnResume = true;
      unawaited(clearNow());
    });
  }

  /// La app volvió a primer plano: si el último borrado por plazo pudo
  /// haberse descartado, se repite ahora, con foco. El adaptador no pisa lo
  /// que otra app haya copiado después.
  Future<void> onResumed() async {
    if (!_retryOnResume) return;
    _retryOnResume = false;
    await _clear();
  }

  /// Borra ya si hay algo copiado pendiente. Devuelve el borrado en curso,
  /// para que quien cierra la app pueda esperarlo aunque lo haya
  /// disparado otro (p. ej. el bloqueo justo antes).
  Future<void> clearNow() {
    _timer?.cancel();
    _timer = null;
    if (_pending) {
      _pending = false;
      _clearing = _clear();
    }
    return _clearing ?? Future.value();
  }

  Future<void> _clear() async {
    try {
      await port.clearIfStillOurs();
    } catch (_) {
      // Sin portapapeles disponible no hay nada más que hacer; nunca debe
      // impedir bloquear ni salir.
    }
  }
}
