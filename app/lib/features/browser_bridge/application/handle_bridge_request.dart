// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Lockspire

import 'package:lockspire_bridge/lockspire_bridge.dart';

import '../../vault/domain/entities/vault.dart';
import '../domain/origin_matcher.dart';

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

  const HandleBridgeRequest({
    required this.currentVault,
    required this.showApp,
    required this.generatePassword,
  });

  Map<String, Object?> call(BridgeRequest request) {
    switch (request) {
      case PingRequest():
        return pongResponse(request.id, locked: currentVault() == null);

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
        final matches =
            vault.entries
                .where((e) => entryMatchesOrigin(e, request.origin))
                .toList()
              ..sort(
                (a, b) =>
                    a.title.toLowerCase().compareTo(b.title.toLowerCase()),
              );
        return credentialsResponse(request.id, [
          for (final entry in matches)
            CredentialSummary(
              entryId: entry.id,
              title: entry.title,
              username: entry.fields['username'] ?? '',
            ),
        ]);

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
