// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Gabriel Ángel Montoya Rico

/// Familia de colores elegida (ver `LockspireThemeFamily` en `design/`).
/// Cada una tiene versión clara y oscura (ADR 0036):
///
/// - [grafito]: la de Lockspire, sobria, y la predeterminada.
/// - [personalizado]: la paleta sale del color que elige el usuario
///   ([AppearancePreference.customColorArgb]).
/// - [sistema]: la paleta sale del color del sistema operativo (Material You
///   en Android, color de acento en escritorio).
/// - Las demás, inspiradas en un sistema operativo.
///
/// Un valor guardado que ya no existe (Cálido, Menta y Lavanda se quitaron
/// el 2026-09-28) vuelve al tema por defecto al leerse.
enum ThemeFamilyId {
  grafito,
  personalizado,
  sistema,
  lineage,
  pixel,
  ubuntu,
  mint,
  windows,
}

/// Los grupos en que se muestran los temas en Apariencia (ADR 0036).
enum ThemeGroup {
  /// Grafito y Personalizado.
  lockspire({ThemeFamilyId.grafito, ThemeFamilyId.personalizado}),

  /// Colores del sistema.
  automatic({ThemeFamilyId.sistema}),

  /// Los inspirados en un sistema operativo.
  operatingSystems({
    ThemeFamilyId.lineage,
    ThemeFamilyId.pixel,
    ThemeFamilyId.ubuntu,
    ThemeFamilyId.mint,
    ThemeFamilyId.windows,
  });

  final Set<ThemeFamilyId> families;
  const ThemeGroup(this.families);
}

/// Idioma de la app (ADR 0032). [system] usa el del sistema operativo:
/// español si es español, inglés en cualquier otro caso.
enum AppLanguage { system, es, en }

/// Claro, oscuro, o según el modo del sistema operativo.
enum AppearanceMode { system, light, dark }

class AppearancePreference {
  final ThemeFamilyId family;
  final AppearanceMode mode;
  final AppLanguage language;

  /// El color del tema [ThemeFamilyId.personalizado], en ARGB. Se guarda
  /// aunque se elija otro tema, para volver a él tal como estaba.
  final int customColorArgb;

  /// Un azul violáceo que da una paleta equilibrada en claro y oscuro.
  static const defaultCustomColorArgb = 0xFF6750A4;

  const AppearancePreference({
    required this.family,
    required this.mode,
    this.language = AppLanguage.system,
    this.customColorArgb = defaultCustomColorArgb,
  });

  /// Grafito, siguiendo el modo del sistema (ADR 0036).
  static const defaults = AppearancePreference(
    family: ThemeFamilyId.grafito,
    mode: AppearanceMode.system,
  );

  AppearancePreference copyWith({
    ThemeFamilyId? family,
    AppearanceMode? mode,
    AppLanguage? language,
    int? customColorArgb,
  }) => AppearancePreference(
    family: family ?? this.family,
    mode: mode ?? this.mode,
    language: language ?? this.language,
    customColorArgb: customColorArgb ?? this.customColorArgb,
  );

  @override
  bool operator ==(Object other) =>
      other is AppearancePreference &&
      other.family == family &&
      other.mode == mode &&
      other.language == language &&
      other.customColorArgb == customColorArgb;

  @override
  int get hashCode => Object.hash(family, mode, language, customColorArgb);
}
