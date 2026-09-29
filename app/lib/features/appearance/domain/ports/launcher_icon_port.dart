// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Gabriel Ángel Montoya Rico

import '../appearance_preference.dart';

/// El ícono de Lockspire en el lanzador de Android (ADR 0031).
abstract class LauncherIconPort {
  /// Deja activo el ícono del tema [family]. No falla: si el sistema no
  /// deja cambiarlo, queda el que estaba.
  Future<void> useThemeIcon(ThemeFamilyId family);
}
