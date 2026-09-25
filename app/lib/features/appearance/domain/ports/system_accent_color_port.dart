// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Lockspire

/// Color del sistema operativo con el que se genera el tema "Colores del
/// sistema": Material You en Android 12+, color de acento en Windows,
/// Linux y macOS. Se devuelve como ARGB (`0xAARRGGBB`) para que el dominio
/// no dependa de Flutter.
abstract interface class SystemAccentColorPort {
  /// `null` si la plataforma no lo ofrece. Nunca lanza.
  Future<int?> accentColorArgb();
}
