// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Gabriel Ángel Montoya Rico

import 'package:lockspire_bridge/lockspire_bridge.dart';

import '../../vault/domain/entities/entry_fields.dart';
import '../../vault/domain/entities/vault.dart';
import '../domain/origin_matcher.dart';
import 'bridge_credential_requests.dart';

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

/// Vincular el sitio actual a una entrada elegida en la extensión (ADR
/// 0015). No cambia nada: pide la confirmación en la ventana de la app.
class BridgeLinkRequests {
  /// La bóveda desbloqueada en este momento, o `null` si está bloqueada.
  final Vault? Function() currentVault;

  /// Muestra la confirmación de vincular un sitio en la app.
  final void Function(LinkRequest request) requestLink;

  const BridgeLinkRequests({
    required this.currentVault,
    required this.requestLink,
  });

  Map<String, Object?> link(RequestLinkOriginRequest request) {
    final vault = currentVault();
    if (vault == null) return unlockRequiredResponse(request.id);
    final entry = passwordEntriesOf(
      vault,
    ).where((e) => e.id == request.entryId).firstOrNull;
    if (entry == null) return errorResponse(request.id, ErrorCode.notFound);
    requestLink(
      LinkRequest(
        entryId: entry.id,
        entryTitle: entry.title,
        currentUrl: entry.fields[EntryFields.url] ?? '',
        newUrl: linkedUrlForOrigin(request.origin),
      ),
    );
    return okResponse(request.id);
  }
}
