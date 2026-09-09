// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Lockspire

import 'package:lockspire/features/vault/domain/ports/vault_storage_port.dart';
import 'package:lockspire/features/vault/domain/vault_file_codec.dart';
import 'package:webdav_client_plus/webdav_client_plus.dart';

import '../domain/ports/sync_credentials_port.dart';
import '../domain/ports/sync_port.dart';

/// Ruta fija del archivo de bóveda en el servidor WebDAV. Sin
/// configuración de carpetas en esta primera pasada (ver docs/STATE.md).
const _remotePath = '/lockspire-vault.lksp';

/// Implementación de [SyncPort] contra un servidor WebDAV, usando
/// `webdav_client_plus`. Mueve bytes opacos (blob único cifrado, ADR
/// 0004) — no necesita la bóveda desbloqueada ni toca claves.
class WebdavSyncAdapter implements SyncPort {
  final WebdavClient _client;

  WebdavSyncAdapter(WebDavCredentials credentials)
    : _client = WebdavClient.basicAuth(
        url: credentials.serverUrl,
        user: credentials.username,
        pwd: credentials.password,
      );

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
