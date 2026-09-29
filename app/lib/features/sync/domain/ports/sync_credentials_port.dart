// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Gabriel Ángel Montoya Rico

/// Credenciales de conexión a un servidor WebDAV.
class WebDavCredentials {
  final String serverUrl;
  final String username;
  final String password;

  const WebDavCredentials({
    required this.serverUrl,
    required this.username,
    required this.password,
  });
}

/// Puerto de almacenamiento de credenciales de sync.
///
/// Las implementaciones (`infrastructure/`) deben usar el almacenamiento
/// seguro del SO (Keystore/Keychain) — nunca texto plano en disco.
abstract class SyncCredentialsPort {
  Future<WebDavCredentials?> read();

  Future<void> save(WebDavCredentials credentials);

  Future<void> clear();
}
