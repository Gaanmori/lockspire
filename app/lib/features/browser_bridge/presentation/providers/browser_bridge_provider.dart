// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Gabriel Ángel Montoya Rico

import 'dart:async';

import 'package:lockspire_bridge/lockspire_bridge.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../appearance/domain/appearance_preference.dart';
import '../../../appearance/presentation/appearance_controller.dart';
import '../../../desktop/presentation/providers/is_desktop_shell_provider.dart';
import '../../../desktop/presentation/window_actions.dart';
import '../../../vault/application/password_generator.dart';
import '../../../vault/presentation/vault_session_controller.dart';
import '../../../vault/presentation/vault_session_state.dart';
import '../../application/handle_bridge_request.dart';
import 'pending_link_request_provider.dart';

part 'browser_bridge_provider.g.dart';

/// Estado del servidor IPC para la extensión (ADR 0013).
enum BrowserBridgeStatus {
  /// Escuchando: la extensión puede conectar.
  running,

  /// Otra instancia de la app ya tiene el canal.
  anotherInstance,

  /// No se pudo arrancar (p. ej. sin `XDG_RUNTIME_DIR`).
  unavailable,

  /// Plataforma sin extensión de navegador (Android).
  unsupported,
}

/// Arranca el servidor IPC una vez por proceso y lo mantiene vivo. Las
/// peticiones leen la sesión de la bóveda en el momento en que llegan —
/// con la bóveda bloqueada no hay nada que devolver (`UNLOCK_REQUIRED`).
@Riverpod(keepAlive: true)
Future<BrowserBridgeStatus> browserBridge(Ref ref) async {
  if (!ref.watch(isDesktopShellProvider)) {
    return BrowserBridgeStatus.unsupported;
  }

  final handle = HandleBridgeRequest(
    currentVault: () {
      final session = ref.read(vaultSessionControllerProvider).value;
      return session is VaultSessionUnlocked ? session.vault : null;
    },
    showApp: () => unawaited(showMainWindow()),
    generatePassword: (length) => generatePassword(length: length),
    requestLink: (request) {
      ref.read(pendingLinkRequestProvider.notifier).set(request);
      unawaited(showMainWindow());
    },
    currentAppearance: () =>
        ref.read(appearanceControllerProvider).value ??
        AppearancePreference.defaults,
  );

  try {
    final server = await BridgeServer.start(
      location: IpcLocation.forCurrentUser(),
      handler: (request, client) async => handle(request),
    );
    ref.onDispose(server.close);
    return BrowserBridgeStatus.running;
  } on BridgeServerAlreadyRunningException {
    return BrowserBridgeStatus.anotherInstance;
  } catch (_) {
    return BrowserBridgeStatus.unavailable;
  }
}
