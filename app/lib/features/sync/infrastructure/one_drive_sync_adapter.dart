// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Lockspire

import 'package:http/http.dart' as http;

import '../../vault/domain/ports/vault_storage_port.dart';
import '../../vault/domain/vault_file_codec.dart';
import '../domain/ports/sync_port.dart';

/// Nombre fijo del archivo de bóveda dentro de la carpeta especial de app
/// de OneDrive (`special/approot`) — mismo criterio que
/// `GoogleDriveSyncAdapter`/`WebdavSyncAdapter`, sin configuración de
/// nombres en esta primera pasada.
const _fileName = 'lockspire-vault.lksp';
const _itemPath =
    'https://graph.microsoft.com/v1.0/me/drive/special/approot:/$_fileName';

/// Implementación de [SyncPort] contra OneDrive, usando Microsoft Graph
/// directamente sobre `special/approot` (scope `Files.ReadWrite.AppFolder`,
/// ver `microsoft_oauth_auth.dart`) — invisible en el OneDrive normal del
/// usuario, equivalente exacto de `appDataFolder` de Google Drive. Mueve
/// bytes opacos (blob único cifrado, ADR 0004), igual que los otros dos
/// adapters — no necesita la bóveda desbloqueada ni toca claves.
///
/// Graph permite direccionar el item por path directo
/// (`special/approot:/$_fileName`) — a diferencia de
/// `GoogleDriveSyncAdapter`, no hace falta buscar ni cachear ningún id de
/// archivo.
///
/// Recibe un access token ya vigente — de dónde sale (login interactivo o
/// refresh) es indistinto para este adapter, ver
/// `sync/presentation/providers/active_sync_port_provider.dart`.
class OneDriveSyncAdapter implements SyncPort {
  final String _accessToken;
  final http.Client _http;

  OneDriveSyncAdapter(this._accessToken, {http.Client? httpClient})
    : _http = httpClient ?? http.Client();

  Map<String, String> get _authHeader => {
    'Authorization': 'Bearer $_accessToken',
  };

  @override
  Future<bool> remoteVaultExists() async {
    final response = await _http.get(
      Uri.parse(_itemPath),
      headers: _authHeader,
    );
    return response.statusCode == 200;
  }

  @override
  Future<VaultFile> downloadVault() async {
    final response = await _http.get(
      Uri.parse('$_itemPath:/content'),
      headers: _authHeader,
    );
    if (response.statusCode != 200) {
      throw StateError('No hay bóveda en OneDrive todavía');
    }
    return VaultFileCodec.decode(response.bodyBytes);
  }

  @override
  Future<void> uploadVault(VaultFile file) async {
    final bytes = VaultFileCodec.encode(file);
    final response = await _http.put(
      Uri.parse('$_itemPath:/content'),
      headers: {..._authHeader, 'Content-Type': 'application/octet-stream'},
      body: bytes,
    );
    if (response.statusCode != 200 && response.statusCode != 201) {
      throw StateError(
        'No se pudo subir la bóveda a OneDrive (${response.statusCode})',
      );
    }
  }
}
