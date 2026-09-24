// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Lockspire

import 'package:lockspire_bridge/lockspire_bridge.dart';

import '../../appearance/domain/appearance_preference.dart';
import '../../vault/domain/entities/vault.dart';
import '../../vault/domain/entities/vault_entry.dart';
import '../domain/origin_matcher.dart';

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

  const HandleBridgeRequest({
    required this.currentVault,
    required this.showApp,
    required this.generatePassword,
    required this.requestLink,
    this.currentAppearance = _defaultAppearance,
  });

  static AppearancePreference _defaultAppearance() =>
      AppearancePreference.defaults;

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

  Map<String, Object?> call(BridgeRequest request) {
    switch (request) {
      case PingRequest():
        final appearance = currentAppearance();
        return pongResponse(
          request.id,
          locked: currentVault() == null,
          themeFamily: appearance.family.name,
          themeMode: appearance.mode.name,
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
