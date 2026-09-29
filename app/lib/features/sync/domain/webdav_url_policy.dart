// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Gabriel Ángel Montoya Rico

/// Por qué no se acepta una URL de servidor WebDAV.
enum WebDavUrlProblem {
  /// No es una URL `http(s)://host/...` válida.
  invalid,

  /// Usa `http://` hacia otro equipo: usuario y contraseña del servidor
  /// viajarían sin cifrar (Basic Auth).
  insecure,
}

const _loopbackHosts = {'localhost', '127.0.0.1', '::1', '[::1]'};

/// Regla de dominio (revisión 2026-09-25, hallazgo S7): se acepta
/// `https://` hacia cualquier servidor, y `http://` **solo** hacia este
/// mismo equipo (el tráfico no sale de la máquina). Devuelve `null` si la
/// URL es aceptable.
///
/// La bóveda viaja cifrada igualmente, pero con `http://` cualquiera en la
/// misma red (p. ej. una Wi-Fi pública) capturaría las credenciales del
/// servidor y podría reemplazar o borrar la copia remota.
WebDavUrlProblem? checkWebDavUrl(String url) {
  final uri = Uri.tryParse(url.trim());
  if (uri == null || uri.host.isEmpty) return WebDavUrlProblem.invalid;
  switch (uri.scheme.toLowerCase()) {
    case 'https':
      return null;
    case 'http':
      return _loopbackHosts.contains(uri.host.toLowerCase())
          ? null
          : WebDavUrlProblem.insecure;
    default:
      return WebDavUrlProblem.invalid;
  }
}
