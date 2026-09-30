// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Gabriel Ángel Montoya Rico

import 'package:lockspire_bridge/lockspire_bridge.dart';

import '../../vault/domain/entities/vault.dart';
import '../domain/browser_login.dart';
import '../domain/ports/login_save_exclusions_port.dart';

/// Guardar inicios de sesión vistos en el navegador (ADR 0034).
class BridgeLoginSaveRequests {
  /// La bóveda desbloqueada en este momento, o `null` si está bloqueada.
  final Vault? Function() currentVault;

  /// Guarda un inicio de sesión que el usuario aceptó en la página: una
  /// entrada nueva, o la contraseña nueva de [LoginMatch].
  final Future<void> Function(BrowserLogin login, LoginMatch match) saveLogin;

  /// Con la bóveda bloqueada: la app lo guarda al desbloquear.
  final void Function(BrowserLogin login) saveAfterUnlock;

  /// Sitios donde el usuario pidió no ofrecer guardar.
  final LoginSaveExclusionsPort exclusions;

  const BridgeLoginSaveRequests({
    required this.currentVault,
    required this.saveLogin,
    required this.saveAfterUnlock,
    required this.exclusions,
  });

  static BrowserLogin _login(LoginRequest request) => BrowserLogin(
    origin: request.origin,
    username: request.username,
    password: request.password,
  );

  Future<Map<String, Object?>> check(CheckLoginRequest request) async {
    final login = _login(request);
    if (await exclusions.isExcluded(login.site)) {
      return loginStatusResponse(request.id, LoginStatus.never);
    }
    final vault = currentVault();
    if (vault == null) return unlockRequiredResponse(request.id);
    return switch (matchLogin(vault, login)) {
      NewLogin() => loginStatusResponse(request.id, LoginStatus.newLogin),
      ChangedPassword(:final entry) => loginStatusResponse(
        request.id,
        LoginStatus.update,
        title: entry.title,
      ),
      AlreadySaved() => loginStatusResponse(request.id, LoginStatus.saved),
    };
  }

  Future<Map<String, Object?>> save(SaveLoginRequest request) async {
    final login = _login(request);
    final vault = currentVault();
    if (vault == null) {
      saveAfterUnlock(login);
      return unlockRequiredResponse(request.id);
    }
    final match = matchLogin(vault, login);
    if (match is! AlreadySaved) await saveLogin(login, match);
    return okResponse(request.id);
  }

  Future<Map<String, Object?>> never(NeverSaveForOriginRequest request) async {
    await exclusions.exclude(
      BrowserLogin(origin: request.origin, username: '', password: '').site,
    );
    return okResponse(request.id);
  }
}
