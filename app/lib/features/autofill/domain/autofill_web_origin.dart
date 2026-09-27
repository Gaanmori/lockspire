// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Lockspire

import '../../browser_bridge/domain/origin_matcher.dart';
import '../../vault/domain/entities/vault_entry.dart';

/// Origen (`esquema://host[:puerto]`) de la página que pide autofill, a
/// partir de lo que informa Android (`ViewNode.getWebDomain()` /
/// `getWebScheme()`), o `null` si no hay página web (app nativa) o el
/// dominio no es válido (ADR 0020).
///
/// Si el esquema no es `https`, o no se conoce (Android 8 no lo informa),
/// se usa `http`: así una entrada guardada como `https` no coincide y se
/// pide confirmación. Ante la duda gana la protección contra downgrade de
/// ADR 0013.
String? webOriginFor({String? webDomain, String? webScheme}) {
  final domain = webDomain?.trim().toLowerCase() ?? '';
  if (domain.isEmpty) return null;
  final scheme = webScheme?.trim().toLowerCase() == 'https' ? 'https' : 'http';
  final uri = Uri.tryParse('$scheme://$domain');
  if (uri == null ||
      uri.host.isEmpty ||
      uri.path.isNotEmpty ||
      uri.hasQuery ||
      uri.hasFragment ||
      uri.userInfo.isNotEmpty) {
    return null;
  }
  return uri.origin;
}

/// Cómo se relaciona una entrada con el sitio que pide autofill.
enum EntrySiteMatch {
  /// Mismo sitio (o subdominio) — se rellena directamente.
  matches,

  /// La entrada es de otro sitio — posible phishing, se advierte.
  otherSite,

  /// La entrada no tiene sitio guardado — se pregunta si recordarlo.
  noSite,
}

/// Mismas reglas que la extensión de escritorio ([entryMatchesOrigin],
/// ADR 0013): host igual o subdominio, sin downgrade `https`→`http`.
EntrySiteMatch classifyEntryForOrigin(VaultEntry entry, String origin) {
  final url = entry.fields['url']?.trim() ?? '';
  if (url.isEmpty) return EntrySiteMatch.noSite;
  return entryMatchesOrigin(entry, origin)
      ? EntrySiteMatch.matches
      : EntrySiteMatch.otherSite;
}

/// Entradas visibles con las del sitio primero. No oculta el resto: el
/// usuario puede necesitar una entrada de otro dominio del mismo servicio
/// (con la advertencia correspondiente al elegirla).
List<VaultEntry> sortEntriesForOrigin({
  required List<VaultEntry> entries,
  required String origin,
}) {
  final visible = entries.where((e) => !e.deleted).toList();
  final matched = <VaultEntry>[];
  final rest = <VaultEntry>[];
  for (final entry in visible) {
    (classifyEntryForOrigin(entry, origin) == EntrySiteMatch.matches
            ? matched
            : rest)
        .add(entry);
  }
  return [...matched, ...rest];
}

/// Nombres legibles de navegadores comunes, solo para mostrar quién pide
/// ("en Chrome"). No se usa para decidir nada de seguridad.
const _knownBrowsers = {
  'com.android.chrome': 'Chrome',
  'com.chrome.beta': 'Chrome Beta',
  'org.mozilla.firefox': 'Firefox',
  'org.mozilla.fenix': 'Firefox',
  'com.microsoft.emmx': 'Edge',
  'com.brave.browser': 'Brave',
  'com.opera.browser': 'Opera',
  'com.sec.android.app.sbrowser': 'Samsung Internet',
  'com.duckduckgo.mobile.android': 'DuckDuckGo',
  'com.vivaldi.browser': 'Vivaldi',
  'com.mi.globalbrowser': 'Mi Browser',
};

/// Texto de quién muestra la página: "en Chrome" o "dentro de la app
/// com.ejemplo". Ver ADR 0020, "Qué se muestra".
String describeRequestingApp(String packageName) {
  final browser = _knownBrowsers[packageName];
  if (browser != null) return 'en $browser';
  if (packageName.isEmpty) return 'en una app desconocida';
  return 'dentro de la app $packageName';
}
