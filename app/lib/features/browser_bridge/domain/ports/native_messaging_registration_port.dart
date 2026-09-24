// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Lockspire

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

  /// Navegadores donde el host está registrado apuntando a esta
  /// instalación.
  final Set<SupportedBrowser> registeredIn;

  const NativeMessagingStatus({
    required this.hostBinaryFound,
    required this.registeredIn,
  });

  bool get isRegistered => registeredIn.isNotEmpty;
}

/// Registro del native host en los navegadores. Solo se modifica cuando
/// el usuario lo pide explícitamente (ADR 0013, opt-in).
abstract interface class NativeMessagingRegistrationPort {
  Future<NativeMessagingStatus> status();

  /// Registra el host en los navegadores soportados. Devuelve en cuáles
  /// quedó registrado.
  Future<Set<SupportedBrowser>> register();

  Future<void> unregister();
}
