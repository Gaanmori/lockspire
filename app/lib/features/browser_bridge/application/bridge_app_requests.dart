// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Gabriel Ángel Montoya Rico

import 'package:lockspire_bridge/lockspire_bridge.dart';

import '../../appearance/domain/appearance_preference.dart';

/// Lo que la extensión pregunta de la app en sí (ADR 0013): si está
/// bloqueada, con qué tema e idioma pintarse, mostrar la ventana y generar
/// una contraseña. Nada de esto lee la bóveda.
class BridgeAppRequests {
  /// `true` si la bóveda está bloqueada.
  final bool Function() isLocked;

  /// Trae la ventana de la app al frente.
  final void Function() showApp;

  /// Generador de contraseñas aleatorias de la app.
  final String Function(int length) generatePassword;

  /// Tema activo de la app, para que la extensión use el mismo.
  final AppearancePreference Function() currentAppearance;

  /// Idioma efectivo de la app ("es", "en"), para que la extensión use el
  /// mismo (ADR 0032). `null` si no se conoce.
  final String? Function() currentLanguage;

  const BridgeAppRequests({
    required this.isLocked,
    required this.showApp,
    required this.generatePassword,
    this.currentAppearance = _defaultAppearance,
    this.currentLanguage = _noLanguage,
  });

  static String? _noLanguage() => null;

  static AppearancePreference _defaultAppearance() =>
      AppearancePreference.defaults;

  Map<String, Object?> ping(PingRequest request) {
    final appearance = currentAppearance();
    return pongResponse(
      request.id,
      locked: isLocked(),
      themeFamily: appearance.family.name,
      themeMode: appearance.mode.name,
      language: currentLanguage(),
    );
  }

  Map<String, Object?> show(ShowAppRequest request) {
    showApp();
    return okResponse(request.id);
  }

  Map<String, Object?> generate(GeneratePasswordRequest request) =>
      generatedPasswordResponse(request.id, generatePassword(request.length));
}
