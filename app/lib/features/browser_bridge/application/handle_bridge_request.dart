// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Gabriel Ángel Montoya Rico

import 'package:lockspire_bridge/lockspire_bridge.dart';

import '../../appearance/domain/appearance_preference.dart';
import '../../vault/domain/entities/vault.dart';
import '../../vault/domain/entities/vault_entry.dart';
import '../domain/browser_login.dart';
import '../domain/origin_matcher.dart';
import '../domain/ports/login_save_exclusions_port.dart';

/// Petición pendiente de vincular un sitio a una entrada (ADR 0015). La
/// confirma el usuario en la ventana de la app, nunca la extensión.
class LinkRequest {
  final String entryId;
  final String entryTitle;

  /// URL que tiene hoy la entrada (vacía si no tenía).
  final String currentUrl;

  /// URL que quedará si el usuario confirma.
  final String newUrl;

  const LinkRequest({
    required this.entryId,
    required this.entryTitle,
    required this.currentUrl,
    required this.newUrl,
  });
}

/// Responde las peticiones de la extensión (ADR 0013). No sabe nada de
/// transporte ni de Riverpod: recibe la bóveda desbloqueada (o `null` si
/// está bloqueada) y efectos inyectados.
class HandleBridgeRequest {
  /// La bóveda desbloqueada en este momento, o `null` si está bloqueada.
  final Vault? Function() currentVault;

  /// Trae la ventana de la app al frente.
  final void Function() showApp;

  /// Generador de contraseñas aleatorias de la app.
  final String Function(int length) generatePassword;

  /// Muestra la confirmación de vincular un sitio en la app (ADR 0015).
  final void Function(LinkRequest request) requestLink;

  /// Tema activo de la app, para que la extensión use el mismo.
  final AppearancePreference Function() currentAppearance;

  /// Idioma efectivo de la app ("es", "en"), para que la extensión use el
  /// mismo (ADR 0032). `null` si no se conoce.
  final String? Function() currentLanguage;

  /// Guarda un inicio de sesión que el usuario aceptó en la página (ADR
  /// 0034): una entrada nueva, o la contraseña nueva de [LoginMatch].
  final Future<void> Function(BrowserLogin login, LoginMatch match) saveLogin;

  /// Con la bóveda bloqueada: la app lo guarda al desbloquear.
  final void Function(BrowserLogin login) saveAfterUnlock;

  /// Sitios donde el usuario pidió no ofrecer guardar.
  final LoginSaveExclusionsPort exclusions;

  const HandleBridgeRequest({
    required this.currentVault,
    required this.showApp,
    required this.generatePassword,
    required this.requestLink,
    required this.saveLogin,
    required this.saveAfterUnlock,
    required this.exclusions,
    this.currentAppearance = _defaultAppearance,
    this.currentLanguage = _noLanguage,
  });

  static String? _noLanguage() => null;

  static AppearancePreference _defaultAppearance() =>
      AppearancePreference.defaults;

  static BrowserLogin _login(LoginRequest request) => BrowserLogin(
    origin: request.origin,
    username: request.username,
    password: request.password,
  );

  static Iterable<VaultEntry> _passwordEntries(Vault vault) => vault.entries
      .where((e) => !e.deleted && e.type == VaultEntryType.password);

  static List<CredentialSummary> _summaries(Iterable<VaultEntry> entries) {
    final sorted = entries.toList()
      ..sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
    return [
      for (final entry in sorted)
        CredentialSummary(
          entryId: entry.id,
          title: entry.title,
          username: entry.fields['username'] ?? '',
        ),
    ];
  }

  Future<Map<String, Object?>> call(BridgeRequest request) async {
    switch (request) {
      case PingRequest():
        final appearance = currentAppearance();
        return pongResponse(
          request.id,
          locked: currentVault() == null,
          themeFamily: appearance.family.name,
          themeMode: appearance.mode.name,
          language: currentLanguage(),
        );

      case ShowAppRequest():
        showApp();
        return okResponse(request.id);

      case GeneratePasswordRequest():
        return generatedPasswordResponse(
          request.id,
          generatePassword(request.length),
        );

      case GetCredentialsRequest():
        final vault = currentVault();
        if (vault == null) return unlockRequiredResponse(request.id);
        return credentialsResponse(
          request.id,
          _summaries(
            vault.entries.where((e) => entryMatchesOrigin(e, request.origin)),
          ),
        );

      case ListCredentialsRequest():
        final vault = currentVault();
        if (vault == null) return unlockRequiredResponse(request.id);
        return credentialsResponse(
          request.id,
          _summaries(_passwordEntries(vault)),
        );

      case RequestLinkOriginRequest():
        final vault = currentVault();
        if (vault == null) return unlockRequiredResponse(request.id);
        final entry = _passwordEntries(
          vault,
        ).where((e) => e.id == request.entryId).firstOrNull;
        if (entry == null) {
          return errorResponse(request.id, ErrorCode.notFound);
        }
        // No se modifica nada aquí: la app pregunta en su propia ventana.
        requestLink(
          LinkRequest(
            entryId: entry.id,
            entryTitle: entry.title,
            currentUrl: entry.fields['url'] ?? '',
            newUrl: linkedUrlForOrigin(request.origin),
          ),
        );
        return okResponse(request.id);

      case CheckLoginRequest():
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

      case SaveLoginRequest():
        final login = _login(request);
        final vault = currentVault();
        if (vault == null) {
          saveAfterUnlock(login);
          return unlockRequiredResponse(request.id);
        }
        final match = matchLogin(vault, login);
        if (match is! AlreadySaved) await saveLogin(login, match);
        return okResponse(request.id);

      case NeverSaveForOriginRequest():
        await exclusions.exclude(
          BrowserLogin(origin: request.origin, username: '', password: '').site,
        );
        return okResponse(request.id);

      case GetCredentialSecretRequest():
        final vault = currentVault();
        if (vault == null) return unlockRequiredResponse(request.id);
        // Mismo NOT_FOUND tanto si el id no existe como si existe pero es
        // de otro sitio: no se revela nada de entradas ajenas al origen.
        final entry = vault.entries
            .where(
              (e) =>
                  e.id == request.entryId &&
                  entryMatchesOrigin(e, request.origin),
            )
            .firstOrNull;
        if (entry == null) {
          return errorResponse(request.id, ErrorCode.notFound);
        }
        return credentialSecretResponse(
          request.id,
          username: entry.fields['username'] ?? '',
          password: entry.fields['password'] ?? '',
        );
    }
  }
}
