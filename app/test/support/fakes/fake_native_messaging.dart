// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Gabriel Ángel Montoya Rico

import 'package:lockspire/features/browser_bridge/domain/ports/native_messaging_registration_port.dart';
import 'package:lockspire/shared/domain/app_problem.dart';

/// Registro del native host en memoria (ADR 0013, 0014).
class FakeNativeMessaging implements NativeMessagingRegistrationPort {
  bool hostBinaryFound = true;
  bool systemWideSupported = true;
  Set<SupportedBrowser> installed = {
    SupportedBrowser.chrome,
    SupportedBrowser.edge,
  };
  Set<SupportedBrowser> registeredIn = {};
  Set<SupportedBrowser> registeredSystemWideIn = {};

  /// Registros que apuntan a otra copia de Lockspire (p. ej. un Debug
  /// viejo). Registrar esta copia los reemplaza.
  Set<SupportedBrowser> otherCopyIn = {};
  Set<SupportedBrowser> otherCopySystemWideIn = {};

  /// El usuario cancela el permiso de administrador.
  bool cancelElevation = false;

  @override
  Future<NativeMessagingStatus> status() async => NativeMessagingStatus(
    hostBinaryFound: hostBinaryFound,
    registeredIn: registeredIn,
    registeredSystemWideIn: registeredSystemWideIn,
    systemWideSupported: systemWideSupported,
    otherCopyIn: otherCopyIn,
    otherCopySystemWideIn: otherCopySystemWideIn,
  );

  @override
  Future<Set<SupportedBrowser>> register() async {
    otherCopyIn = {};
    return registeredIn = {...installed};
  }

  @override
  Future<void> unregister() async => registeredIn = {};

  @override
  Future<void> registerSystemWide() async {
    if (cancelElevation) {
      throw const AppProblem(AppProblemCode.nativeHostElevationCancelled);
    }
    otherCopySystemWideIn = {};
    registeredSystemWideIn = {...installed};
  }

  @override
  Future<void> unregisterSystemWide() async {
    otherCopySystemWideIn = {};
    registeredSystemWideIn = {};
  }
}
