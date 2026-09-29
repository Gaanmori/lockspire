// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Gabriel Ángel Montoya Rico

/// Navegadores Chromium donde se registra el native host (ADR 0013).
enum SupportedBrowser {
  chrome('Google Chrome'),
  edge('Microsoft Edge'),
  chromium('Chromium');

  final String displayName;
  const SupportedBrowser(this.displayName);
}

/// Estado del registro del native host.
class NativeMessagingStatus {
  /// `false` si el binario del host no está junto a la app: no se puede
  /// registrar nada.
  final bool hostBinaryFound;

  /// Navegadores donde el host está registrado para el usuario actual,
  /// apuntando a esta instalación.
  final Set<SupportedBrowser> registeredIn;

  /// Navegadores donde el host está registrado para todo el equipo (ADR
  /// 0014). Vacío si no aplica en la plataforma.
  final Set<SupportedBrowser> registeredSystemWideIn;

  /// `true` si la plataforma admite el registro para todo el equipo.
  final bool systemWideSupported;

  const NativeMessagingStatus({
    required this.hostBinaryFound,
    required this.registeredIn,
    this.registeredSystemWideIn = const {},
    this.systemWideSupported = false,
  });

  bool get isRegistered => registeredIn.isNotEmpty;

  bool get isRegisteredSystemWide => registeredSystemWideIn.isNotEmpty;
}

/// Registro del native host en los navegadores. Solo se modifica cuando
/// el usuario lo pide explícitamente (ADR 0013, opt-in).
abstract interface class NativeMessagingRegistrationPort {
  Future<NativeMessagingStatus> status();

  /// Registra el host en los navegadores soportados. Devuelve en cuáles
  /// quedó registrado.
  Future<Set<SupportedBrowser>> register();

  Future<void> unregister();

  /// Registra el host para todo el equipo (ADR 0014). Pide permisos de
  /// administrador al sistema. Pensado para equipos donde una política de
  /// la organización impide los hosts por usuario
  /// (`NativeMessagingUserLevelHosts`). Lanza si el usuario cancela la
  /// elevación o falla.
  Future<void> registerSystemWide();

  /// Quita el registro para todo el equipo. También pide elevación.
  Future<void> unregisterSystemWide();
}
