// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Lockspire

/// Familia de colores elegida (ver `LockspireThemeFamily` en `design/`).
/// Cada una tiene versión clara y oscura.
enum ThemeFamilyId { calido, menta, lavanda }

/// Claro, oscuro, o según el modo del sistema operativo.
enum AppearanceMode { system, light, dark }

class AppearancePreference {
  final ThemeFamilyId family;
  final AppearanceMode mode;

  const AppearancePreference({required this.family, required this.mode});

  /// Cálido, siguiendo el modo del sistema.
  static const defaults = AppearancePreference(
    family: ThemeFamilyId.calido,
    mode: AppearanceMode.system,
  );

  AppearancePreference copyWith({
    ThemeFamilyId? family,
    AppearanceMode? mode,
  }) => AppearancePreference(
    family: family ?? this.family,
    mode: mode ?? this.mode,
  );

  @override
  bool operator ==(Object other) =>
      other is AppearancePreference &&
      other.family == family &&
      other.mode == mode;

  @override
  int get hashCode => Object.hash(family, mode);
}
