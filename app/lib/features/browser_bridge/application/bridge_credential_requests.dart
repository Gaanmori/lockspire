// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Gabriel Ángel Montoya Rico

import 'package:lockspire_bridge/lockspire_bridge.dart';

import '../../vault/domain/entities/entry_fields.dart';
import '../../vault/domain/entities/vault.dart';
import '../../vault/domain/entities/vault_entry.dart';
import '../domain/origin_matcher.dart';

/// Las contraseñas de la bóveda que puede ver la extensión (sin borrar).
Iterable<VaultEntry> passwordEntriesOf(Vault vault) =>
    vault.entries.where((e) => !e.deleted && e.type == VaultEntryType.password);

/// Leer credenciales para rellenar (ADR 0013): resúmenes sin contraseña, y
/// el secreto de una entrada solo si es del sitio que lo pide.
class BridgeCredentialRequests {
  /// La bóveda desbloqueada en este momento, o `null` si está bloqueada.
  final Vault? Function() currentVault;

  const BridgeCredentialRequests({required this.currentVault});

  static List<CredentialSummary> _summaries(Iterable<VaultEntry> entries) {
    final sorted = entries.toList()
      ..sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
    return [
      for (final entry in sorted)
        CredentialSummary(
          entryId: entry.id,
          title: entry.title,
          username: entry.fields[EntryFields.username] ?? '',
        ),
    ];
  }

  Map<String, Object?> forOrigin(GetCredentialsRequest request) {
    final vault = currentVault();
    if (vault == null) return unlockRequiredResponse(request.id);
    return credentialsResponse(
      request.id,
      _summaries(
        vault.entries.where((e) => entryMatchesOrigin(e, request.origin)),
      ),
    );
  }

  /// Todas, para elegir una a mano y vincularla al sitio (ADR 0015).
  Map<String, Object?> all(ListCredentialsRequest request) {
    final vault = currentVault();
    if (vault == null) return unlockRequiredResponse(request.id);
    return credentialsResponse(
      request.id,
      _summaries(passwordEntriesOf(vault)),
    );
  }

  Map<String, Object?> secret(GetCredentialSecretRequest request) {
    final vault = currentVault();
    if (vault == null) return unlockRequiredResponse(request.id);
    // Mismo NOT_FOUND tanto si el id no existe como si existe pero es de
    // otro sitio: no se revela nada de entradas ajenas al origen.
    final entry = vault.entries
        .where(
          (e) =>
              e.id == request.entryId && entryMatchesOrigin(e, request.origin),
        )
        .firstOrNull;
    if (entry == null) return errorResponse(request.id, ErrorCode.notFound);
    return credentialSecretResponse(
      request.id,
      username: entry.fields[EntryFields.username] ?? '',
      password: entry.fields[EntryFields.password] ?? '',
    );
  }
}
