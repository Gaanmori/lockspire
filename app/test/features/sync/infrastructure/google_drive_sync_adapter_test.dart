// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Gabriel Ángel Montoya Rico

import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:googleapis_auth/googleapis_auth.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:lockspire/features/sync/infrastructure/google_drive_sync_adapter.dart';
import 'package:lockspire/features/vault/domain/vault_file_codec.dart';
import 'package:lockspire/shared/domain/app_problem.dart';

import '../../../support/builders.dart';

/// Google Drive en memoria: la carpeta oculta de la app (`appDataFolder`)
/// con a lo sumo un archivo. Entiende las llamadas que hace `googleapis`.
class _FakeDrive {
  Uint8List? stored;
  String? storedName;
  final requests = <http.Request>[];

  late final client = MockClient((request) async {
    requests.add(request);
    final path = request.url.path;
    final json = {'content-type': 'application/json; charset=utf-8'};

    if (request.method == 'GET' && path == '/drive/v3/files') {
      expect(request.url.queryParameters['spaces'], 'appDataFolder');
      final files = stored == null
          ? []
          : [
              {'id': 'f1'},
            ];
      return http.Response(jsonEncode({'files': files}), 200, headers: json);
    }
    if (request.method == 'GET' && path == '/drive/v3/files/f1') {
      return http.Response.bytes(
        stored!,
        200,
        headers: {'content-type': 'application/octet-stream'},
      );
    }
    if (path.startsWith('/upload/drive/v3/files')) {
      final (metadata, bytes) = _multipart(request);
      stored = bytes;
      if (request.method == 'POST') storedName = metadata['name'] as String?;
      return http.Response(jsonEncode({'id': 'f1'}), 200, headers: json);
    }
    return http.Response('', 404);
  });

  /// Separa el cuerpo "multipart/related": metadatos JSON y contenido.
  static (Map<String, Object?>, Uint8List) _multipart(http.Request request) {
    final boundary = RegExp(
      r'boundary="?([^";]+)"?',
    ).firstMatch(request.headers['content-type']!)!.group(1)!;
    final parts = request.body
        .split('--$boundary')
        .map((p) => p.trim())
        .where((p) => p.isNotEmpty && p != '--')
        .toList();
    String bodyOf(String part) => part.substring(part.indexOf('\r\n\r\n') + 4);
    final metadata = jsonDecode(bodyOf(parts[0])) as Map<String, Object?>;
    final media = parts[1];
    final raw = bodyOf(media).trim();
    final bytes = media.toLowerCase().contains('base64')
        ? base64Decode(raw.replaceAll(RegExp(r'\s'), ''))
        : Uint8List.fromList(latin1.encode(raw));
    return (metadata, Uint8List.fromList(bytes));
  }
}

AuthClient _authClient(http.Client base) => authenticatedClient(
  base,
  AccessCredentials(
    AccessToken(
      'Bearer',
      'token-1',
      DateTime.now().toUtc().add(const Duration(hours: 1)),
    ),
    null,
    const ['https://www.googleapis.com/auth/drive.appdata'],
  ),
);

void main() {
  late _FakeDrive drive;
  late GoogleDriveSyncAdapter adapter;

  setUp(() {
    drive = _FakeDrive();
    adapter = GoogleDriveSyncAdapter(_authClient(drive.client));
  });

  test('sin archivo en la carpeta de la app, la bóveda no existe y bajarla '
      'falla con un error claro', () async {
    expect(await adapter.remoteVaultExists(), isFalse);
    await expectLater(
      adapter.downloadVault(),
      throwsA(
        isA<AppProblem>()
            .having((e) => e.code, 'code', AppProblemCode.remoteVaultMissing)
            .having((e) => e.detail, 'detail', 'Google Drive'),
      ),
    );
  });

  test('la primera subida crea el archivo en la carpeta oculta de la app y '
      'se puede bajar igual', () async {
    final file = aVaultFile([9, 8, 7]);

    await adapter.uploadVault(file);

    final create = drive.requests.firstWhere((r) => r.method == 'POST');
    expect(create.url.path, '/upload/drive/v3/files');
    expect(drive.storedName, isNotNull);
    expect(await adapter.remoteVaultExists(), isTrue);
    final back = await adapter.downloadVault();
    expect(VaultFileCodec.encode(back), VaultFileCodec.encode(file));
  });

  test(
    'las subidas siguientes actualizan el mismo archivo, no crean otro',
    () async {
      await adapter.uploadVault(aVaultFile([1]));
      await adapter.uploadVault(aVaultFile([2]));

      expect(drive.requests.where((r) => r.method == 'POST'), hasLength(1));
      final update = drive.requests.lastWhere(
        (r) => r.url.path.startsWith('/upload/'),
      );
      expect(update.method, 'PATCH');
      expect(update.url.path, '/upload/drive/v3/files/f1');
      expect(
        VaultFileCodec.encode(await adapter.downloadVault()),
        VaultFileCodec.encode(aVaultFile([2])),
      );
    },
  );

  test('un adaptador nuevo encuentra el archivo que subió otro', () async {
    await adapter.uploadVault(aVaultFile([5]));

    final other = GoogleDriveSyncAdapter(_authClient(drive.client));

    expect(await other.remoteVaultExists(), isTrue);
    expect(
      VaultFileCodec.encode(await other.downloadVault()),
      VaultFileCodec.encode(aVaultFile([5])),
    );
  });
}
