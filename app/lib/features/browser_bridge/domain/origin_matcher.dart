// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Lockspire

import '../../vault/domain/entities/entry_fields.dart';
import '../../vault/domain/entities/vault_entry.dart';

/// ¿Puede la extensión rellenar [entry] en una página de [origin]? (ADR
/// 0013, "Matching de origen").
///
/// - Solo entradas de contraseña no borradas, con alguna URL parseable
///   (cualquiera de sus sitios, ADR 0025).
/// - Host igual, o [origin] subdominio del host guardado
///   (`login.example.com` sí para una entrada `example.com`; al revés no).
/// - Una entrada guardada como `https` nunca coincide con una página
///   `http` (protección contra downgrade). Sin esquema se asume `https`.
/// - Si la entrada fija un puerto explícito, tiene que coincidir.
///
/// Limitación conocida: no convierte dominios internacionales a punycode;
/// una entrada guardada como `ñandú.com` no coincide con el origen
/// `https://xn--and-6ma2c.com` que envía el navegador.
bool entryMatchesOrigin(VaultEntry entry, String origin) {
  if (entry.deleted || entry.type != VaultEntryType.password) return false;
  // Cualquiera de los sitios de la entrada (ADR 0025).
  return entry.urls.any((url) => _urlMatchesOrigin(url, origin));
}

bool _urlMatchesOrigin(String url, String origin) {
  final stored = _parseStoredUrl(url);
  final request = Uri.tryParse(origin);
  if (stored == null || request == null) return false;
  if (!_webSchemes.contains(request.scheme) || request.host.isEmpty) {
    return false;
  }

  if (stored.scheme == 'https' && request.scheme != 'https') return false;
  if (stored.hasPort && stored.port != request.port) return false;

  final storedHost = _normalizeHost(stored.host);
  final requestHost = _normalizeHost(request.host);
  if (storedHost.isEmpty) return false;
  return requestHost == storedHost || requestHost.endsWith('.$storedHost');
}

/// URL que se guarda en una entrada al vincularla con [origin] desde la
/// extensión (ADR 0015): el mismo origen sin un `www.` inicial, para que
/// la entrada coincida también con los demás subdominios del sitio
/// (`https://www.facebook.com` → `https://facebook.com`, que sirve para
/// `www.` y `m.`). Solo se quita `www.`: nunca se sube más allá, porque
/// eso haría coincidir dominios ajenos (`co.uk`).
String linkedUrlForOrigin(String origin) {
  final uri = Uri.parse(origin);
  final host = _normalizeHost(uri.host);
  final stripped = host.startsWith('www.') && host.split('.').length > 2
      ? host.substring(4)
      : host;
  return uri.replace(host: stripped).toString();
}

const _webSchemes = {'http', 'https'};

Uri? _parseStoredUrl(String? raw) {
  final value = raw?.trim();
  if (value == null || value.isEmpty) return null;
  final withScheme = value.contains('://') ? value : 'https://$value';
  final uri = Uri.tryParse(withScheme);
  if (uri == null || !_webSchemes.contains(uri.scheme.toLowerCase())) {
    return null;
  }
  return uri;
}

String _normalizeHost(String host) {
  final lower = host.toLowerCase();
  return lower.endsWith('.') ? lower.substring(0, lower.length - 1) : lower;
}
