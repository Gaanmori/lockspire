// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Gabriel Ángel Montoya Rico

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:lockspire/features/sync/infrastructure/one_drive_sync_adapter.dart';
import 'package:lockspire/features/vault/domain/vault_file_codec.dart';
import 'package:lockspire/shared/domain/app_problem.dart';

import '../../../support/builders.dart';

/// La carpeta de app de OneDrive (Microsoft Graph) en memoria: guarda el
/// archivo, exige el token y registra lo que se pidió.
class _FakeGraph {
  Uint8List? stored;
  int uploadStatus = 201;
  final requests = <http.Request>[];

  late final client = MockClient((request) async {
    requests.add(request);
    if (request.headers['Authorization'] != 'Bearer token-1') {
      return http.Response('', 401);
    }
    final isContent = request.url.path.endsWith(':/content');
    switch (request.method) {
      case 'GET' when isContent:
        return stored == null
            ? http.Response('', 404)
            : http.Response.bytes(stored!, 200);
      case 'GET':
        return http.Response(
          stored == null ? '' : '{}',
          stored == null ? 404 : 200,
        );
      case 'PUT':
        if (uploadStatus < 300) stored = request.bodyBytes;
        return http.Response('{}', uploadStatus);
    }
    return http.Response('', 405);
  });
}

void main() {
  late _FakeGraph graph;
  late OneDriveSyncAdapter adapter;

  setUp(() {
    graph = _FakeGraph();
    adapter = OneDriveSyncAdapter('token-1', httpClient: graph.client);
  });

  test(
    'sin archivo, la bóveda no existe y bajarla falla con un error claro',
    () async {
      expect(await adapter.remoteVaultExists(), isFalse);
      await expectLater(
        adapter.downloadVault(),
        throwsA(
          isA<AppProblem>()
              .having((e) => e.code, 'code', AppProblemCode.remoteVaultMissing)
              .having((e) => e.detail, 'detail', 'OneDrive'),
        ),
      );
    },
  );

  test(
    'sube y baja el mismo archivo, en la carpeta de la app y con el token',
    () async {
      final file = aVaultFile([9, 8, 7]);

      await adapter.uploadVault(file);

      expect(await adapter.remoteVaultExists(), isTrue);
      final back = await adapter.downloadVault();
      expect(VaultFileCodec.encode(back), VaultFileCodec.encode(file));
      final upload = graph.requests.firstWhere((r) => r.method == 'PUT');
      expect(upload.url.path, contains('/me/drive/special/approot'));
      expect(upload.headers['Content-Type'], 'application/octet-stream');
    },
  );

  test(
    'si Graph rechaza la subida, falla con el código de respuesta',
    () async {
      graph.uploadStatus = 507;

      await expectLater(
        adapter.uploadVault(aVaultFile()),
        throwsA(
          isA<AppProblem>()
              .having((e) => e.code, 'code', AppProblemCode.remoteUploadFailed)
              .having((e) => e.detail, 'detail', 'OneDrive (507)'),
        ),
      );
    },
  );
}
