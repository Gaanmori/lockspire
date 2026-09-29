// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Gabriel Ángel Montoya Rico

/// Portapapeles para secretos (revisión 2026-09-25, hallazgo S4). Cada
/// adaptador usa lo que su plataforma ofrece para que lo copiado no quede
/// guardado en otro lado: Android lo marca como sensible; Windows lo deja
/// fuera del historial (Win+V) y del portapapeles en la nube.
abstract class SecureClipboardPort {
  /// Copia [text] marcado como sensible. [clearAfter] es el plazo tras el
  /// que se debe borrar: los adaptadores cuya app puede quedar congelada en
  /// segundo plano (Android) programan el borrado en el sistema, porque ahí
  /// el temporizador de `ClipboardGuard` no corre.
  Future<void> copySensitive(String text, {required Duration clearAfter});

  /// Vacía el portapapeles si todavía tiene lo último copiado con
  /// [copySensitive]. Si otra app copió algo después, no lo toca.
  Future<void> clearIfStillOurs();
}
