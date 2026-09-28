// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Lockspire

import '../../browser_bridge/domain/origin_matcher.dart';
import '../../vault/domain/entities/entry_fields.dart';
import '../../vault/domain/entities/vault_entry.dart';

/// Una cuenta que el servicio de autofill nativo puede ofrecer sin abrir
/// Lockspire mientras dura la sesión de autofill (ADR 0026).
class AutofillSessionItem {
  final String title;
  final String username;
  final String password;
  final List<StoredSite> sites;
  final List<String> apps;

  const AutofillSessionItem({
    required this.title,
    required this.username,
    required this.password,
    required this.sites,
    required this.apps,
  });

  Map<String, Object> toChannel() => {
    'title': title,
    'username': username,
    'password': password,
    'hosts': [for (final s in sites) s.host],
    'httpsOnly': [for (final s in sites) s.httpsOnly],
    'apps': apps,
  };
}

/// Lo mínimo que el servicio nativo necesita: solo contraseñas con algo
/// con qué coincidir (un sitio o una app). El resto nunca sale de Dart.
List<AutofillSessionItem> autofillSessionItems(Iterable<VaultEntry> entries) {
  final items = <AutofillSessionItem>[];
  for (final entry in entries) {
    if (entry.deleted || entry.type != VaultEntryType.password) continue;
    final password = entry.fields[EntryFields.password] ?? '';
    if (password.isEmpty) continue;
    final sites = [
      for (final url in entry.urls) ?storedSiteForNativeAutofill(url),
    ];
    final apps = entry.apps;
    if (sites.isEmpty && apps.isEmpty) continue;
    items.add(
      AutofillSessionItem(
        title: entry.title,
        username: entry.fields[EntryFields.username] ?? '',
        password: password,
        sites: sites,
        apps: apps,
      ),
    );
  }
  return items;
}
