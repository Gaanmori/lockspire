// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Gabriel Ángel Montoya Rico

import 'dart:convert';

import '../domain/ports/site_icon_fetcher_port.dart';

/// Busca los íconos de [hosts] de a pocos a la vez (ADR 0029). Devuelve
/// host → PNG en base64, o `''` si el sitio no tiene uno: así no se vuelve
/// a consultar. Un error de red cuenta como "sin ícono" solo si el sitio
/// respondió; si no hubo conexión, el host se omite para reintentar luego.
class FetchSiteIconsUseCase {
  final SiteIconFetcherPort fetcher;
  final int concurrency;

  /// Qué se guarda si no hay ícono: `''` tras preguntarle al sitio, `'-'`
  /// tras preguntarle a DuckDuckGo (ver `site_icons.dart`).
  final String missingMarker;

  const FetchSiteIconsUseCase({
    required this.fetcher,
    this.concurrency = 4,
    this.missingMarker = '',
  });

  Future<Map<String, String>> call(Iterable<String> hosts) async {
    final queue = hosts.toList();
    final found = <String, String>{};
    Future<void> worker() async {
      while (queue.isNotEmpty) {
        final host = queue.removeLast();
        try {
          final png = await fetcher.fetchPng(host);
          found[host] = png == null ? missingMarker : base64Encode(png);
        } on SiteIconOfflineException {
          // Sin conexión: se reintenta en otro momento.
        } catch (_) {
          found[host] = missingMarker;
        }
      }
    }

    await Future.wait([for (var i = 0; i < concurrency; i++) worker()]);
    return found;
  }
}
