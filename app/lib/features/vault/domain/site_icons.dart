// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Gabriel Ángel Montoya Rico

import 'entities/entry_fields.dart';
import 'entities/vault.dart';
import 'entities/vault_entry.dart';

/// Sitio cuyo ícono representa a [entry] (ADR 0029): el host de su primer
/// sitio web, en minúsculas y sin `www.`. `null` si no tiene sitio.
String? iconHostOf(VaultEntry entry) {
  for (final url in entry.urls) {
    final withScheme = url.contains('://') ? url : 'https://$url';
    final host = Uri.tryParse(withScheme)?.host.toLowerCase() ?? '';
    if (host.isEmpty) continue;
    return host.startsWith('www.') ? host.substring(4) : host;
  }
  return null;
}

final _ipv4 = RegExp(r'^\d{1,3}(\.\d{1,3}){3}$');

/// Solo se consultan nombres públicos: nunca `localhost`, direcciones IP ni
/// nombres sin punto o de red local. Así activar los íconos no hace que la
/// app sondee la red de la casa u oficina (router, NAS…).
bool isFetchableIconHost(String host) {
  if (host.isEmpty || !host.contains('.')) return false;
  if (host == 'localhost' || host.endsWith('.localhost')) return false;
  if (host.endsWith('.local') || host.endsWith('.lan')) return false;
  if (host.endsWith('.internal') || host.endsWith('.home.arpa')) return false;
  if (_ipv4.hasMatch(host) || host.contains(':')) return false;
  return true;
}

/// Valor de `Vault.siteIcons` para "el sitio no ofrece ícono" (se puede
/// completar con DuckDuckGo, ADR 0030).
const noIconFromSite = '';

/// "Ni el sitio ni DuckDuckGo tienen ícono": no se vuelve a preguntar.
const noIconAnywhere = '-';

/// Si [value] es un ícono de verdad y no un marcador.
bool isSiteIcon(String? value) => value != null && value.length > 1;

/// Sitios de entradas vivas que todavía no tienen ícono ni se buscaron.
Set<String> hostsMissingIcons(Vault vault) => {
  for (final entry in vault.entries)
    if (!entry.deleted)
      if (iconHostOf(entry) case final host?)
        if (isFetchableIconHost(host) && !vault.siteIcons.containsKey(host))
          host,
};

/// Sitios de entradas vivas donde el sitio no ofreció ícono y todavía no se
/// le preguntó a DuckDuckGo (ADR 0030).
Set<String> hostsForIconFallback(Vault vault) => {
  for (final entry in vault.entries)
    if (!entry.deleted)
      if (iconHostOf(entry) case final host?)
        if (vault.siteIcons[host] == noIconFromSite) host,
};

final _letterOrDigit = RegExp(r'[\p{L}\p{N}]', unicode: true);

/// Letra para el ícono cuando no hay imagen: el primer carácter útil del
/// título ("::.SM4 Web.::" → S), o si no tiene, del sitio. Antes se tomaba
/// el primer carácter tal cual y salían ":" o ".".
String entryInitial(VaultEntry entry) {
  for (final text in [entry.title, iconHostOf(entry) ?? '']) {
    final match = _letterOrDigit.firstMatch(text);
    if (match != null) return match.group(0)!.toUpperCase();
  }
  return '?';
}
