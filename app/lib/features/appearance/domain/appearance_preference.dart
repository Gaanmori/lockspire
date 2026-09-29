// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Gabriel Ángel Montoya Rico

/// Familia de colores elegida (ver `LockspireThemeFamily` en `design/`).
/// Cada una tiene versión clara y oscura. [sistema] genera la paleta a partir
/// del color del sistema operativo (Material You en Android, color de acento
/// en escritorio).
///
/// Un valor guardado que ya no existe (Cálido, Menta y Lavanda se quitaron
/// el 2026-09-28) vuelve al tema por defecto al leerse.
enum ThemeFamilyId { lineage, pixel, ubuntu, mint, windows, sistema }

/// Idioma de la app (ADR 0032). [system] usa el del sistema operativo:
/// español si es español, inglés en cualquier otro caso.
enum AppLanguage { system, es, en }

/// Claro, oscuro, o según el modo del sistema operativo.
enum AppearanceMode { system, light, dark }

class AppearancePreference {
  final ThemeFamilyId family;
  final AppearanceMode mode;
  final AppLanguage language;

  const AppearancePreference({
    required this.family,
    required this.mode,
    this.language = AppLanguage.system,
  });

  /// Lineage, siguiendo el modo del sistema.
  static const defaults = AppearancePreference(
    family: ThemeFamilyId.lineage,
    mode: AppearanceMode.system,
  );

  AppearancePreference copyWith({
    ThemeFamilyId? family,
    AppearanceMode? mode,
    AppLanguage? language,
  }) => AppearancePreference(
    family: family ?? this.family,
    mode: mode ?? this.mode,
    language: language ?? this.language,
  );

  @override
  bool operator ==(Object other) =>
      other is AppearancePreference &&
      other.family == family &&
      other.mode == mode &&
      other.language == language;

  @override
  int get hashCode => Object.hash(family, mode, language);
}
