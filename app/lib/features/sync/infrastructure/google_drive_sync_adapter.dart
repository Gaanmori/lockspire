// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Lockspire

import 'dart:typed_data';

import 'package:googleapis/drive/v3.dart' as drive;
import 'package:googleapis_auth/googleapis_auth.dart' show AuthClient;

import '../../vault/domain/ports/vault_storage_port.dart';
import '../../vault/domain/vault_file_codec.dart';
import '../domain/ports/sync_port.dart';

/// Nombre fijo del archivo de bóveda dentro de la carpeta oculta
/// `appDataFolder` — igual criterio que `WebdavSyncAdapter._remotePath`,
/// sin configuración de nombres en esta primera pasada.
const _fileName = 'lockspire-vault.lksp';

/// Implementación de [SyncPort] contra Google Drive, usando
/// `package:googleapis`'s `DriveApi` sobre el espacio `appDataFolder`
/// (scope `drive.appdata`, ver `google_drive_scopes.dart`) — invisible en
/// el Drive normal del usuario. Mueve bytes opacos (blob único cifrado,
/// ADR 0004), igual que `WebdavSyncAdapter` — no necesita la bóveda
/// desbloqueada ni toca claves.
///
/// Recibe un [AuthClient] ya autenticado — de dónde sale (Android vía
/// `google_sign_in`, Windows vía el flujo loopback de `googleapis_auth`)
/// es indistinto para este adapter, ver
/// `sync/presentation/providers/active_sync_port_provider.dart`.
class GoogleDriveSyncAdapter implements SyncPort {
  final drive.DriveApi _api;

  String? _cachedFileId;

  GoogleDriveSyncAdapter(AuthClient httpClient)
    : _api = drive.DriveApi(httpClient);

  Future<String?> _findFileId() async {
    if (_cachedFileId != null) return _cachedFileId;
    final result = await _api.files.list(
      spaces: 'appDataFolder',
      q: "name='$_fileName' and trashed=false",
      $fields: 'files(id)',
    );
    final files = result.files;
    if (files == null || files.isEmpty) return null;
    _cachedFileId = files.first.id;
    return _cachedFileId;
  }

  @override
  Future<bool> remoteVaultExists() async => (await _findFileId()) != null;

  @override
  Future<VaultFile> downloadVault() async {
    final fileId = await _findFileId();
    if (fileId == null) {
      throw StateError('No hay bóveda en Google Drive todavía');
    }
    final media =
        await _api.files.get(
              fileId,
              downloadOptions: drive.DownloadOptions.fullMedia,
            )
            as drive.Media;
    final bytes = <int>[];
    await for (final chunk in media.stream) {
      bytes.addAll(chunk);
    }
    return VaultFileCodec.decode(Uint8List.fromList(bytes));
  }

  @override
  Future<void> uploadVault(VaultFile file) async {
    final bytes = VaultFileCodec.encode(file);
    final media = drive.Media(Stream.value(bytes), bytes.length);
    final fileId = await _findFileId();
    if (fileId == null) {
      final created = await _api.files.create(
        drive.File(name: _fileName, parents: ['appDataFolder']),
        uploadMedia: media,
      );
      _cachedFileId = created.id;
    } else {
      await _api.files.update(drive.File(), fileId, uploadMedia: media);
    }
  }
}
