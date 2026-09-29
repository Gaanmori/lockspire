// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Gabriel Ángel Montoya Rico

/// Versión instalada de la app.
class AppVersion {
  final String version;
  final String build;

  const AppVersion({required this.version, required this.build});
}

/// Datos de la app instalada que da la plataforma.
abstract class AppInfoPort {
  Future<AppVersion> version();
}
