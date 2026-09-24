// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Lockspire

import '../../vault/domain/entities/vault_entry.dart';

/// ¿Puede la extensión rellenar [entry] en una página de [origin]? (ADR
/// 0013, "Matching de origen").
///
/// - Solo entradas de contraseña no borradas, con una URL parseable.
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
  final stored = _parseStoredUrl(entry.fields['url']);
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
