// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Lockspire

import 'package:lockspire/features/vault/domain/ports/vault_storage_port.dart';
import 'package:lockspire/features/vault/domain/vault_file_codec.dart';
import 'package:webdav_client_plus/webdav_client_plus.dart';

import '../domain/ports/sync_credentials_port.dart';
import '../domain/ports/sync_port.dart';
import '../domain/webdav_url_policy.dart';

/// Ruta fija del archivo de bóveda en el servidor WebDAV. Sin
/// configuración de carpetas en esta primera pasada (ver docs/STATE.md).
const _remotePath = '/lockspire-vault.lksp';

/// Implementación de [SyncPort] contra un servidor WebDAV, usando
/// `webdav_client_plus`. Mueve bytes opacos (blob único cifrado, ADR
/// 0004) — no necesita la bóveda desbloqueada ni toca claves.
class WebdavSyncAdapter implements SyncPort {
  final WebdavClient _client;

  /// Lanza [StateError] si la URL no cumple [checkWebDavUrl] — defensa en
  /// profundidad para credenciales guardadas antes de que existiera la
  /// regla: nunca se envían por `http://` a otro equipo.
  WebdavSyncAdapter(WebDavCredentials credentials)
    : _client = WebdavClient.basicAuth(
        url: _requireAcceptableUrl(credentials.serverUrl),
        user: credentials.username,
        pwd: credentials.password,
      );

  static String _requireAcceptableUrl(String url) {
    switch (checkWebDavUrl(url)) {
      case null:
        return url;
      case WebDavUrlProblem.insecure:
        throw StateError(
          'El servidor WebDAV usa http:// sin cifrar. Cambiá la URL a '
          'https:// en Sincronización.',
        );
      case WebDavUrlProblem.invalid:
        throw StateError('La URL del servidor WebDAV no es válida.');
    }
  }

  @override
  Future<bool> remoteVaultExists() async {
    // HEAD en vez de exists() (que usa PROPFIND/XML por dentro) — más
    // simple y suficiente: solo nos interesa si el archivo está o no.
    final resp = await _client.head(_remotePath);
    return resp.statusCode == 200;
  }

  @override
  Future<VaultFile> downloadVault() async {
    final bytes = await _client.read(_remotePath);
    return VaultFileCodec.decode(bytes);
  }

  @override
  Future<void> uploadVault(VaultFile file) {
    final bytes = VaultFileCodec.encode(file);
    return _client.write(_remotePath, bytes);
  }
}
