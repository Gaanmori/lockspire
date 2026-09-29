// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Gabriel Ángel Montoya Rico

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:lockspire/features/sync/domain/ports/sync_credentials_port.dart';
import 'package:lockspire/features/sync/infrastructure/webdav_sync_adapter.dart';
import 'package:lockspire/features/vault/domain/ports/vault_storage_port.dart';

const _remotePath = '/lockspire-vault.lksp';
const _username = 'usuario';
const _password = 'contraseña-del-servidor';

/// Servidor WebDAV mínimo real (sobre `dart:io`, sin mocks) que solo
/// entiende lo que `WebdavSyncAdapter` realmente usa contra un path fijo
/// de raíz: HEAD/GET/PUT con Basic Auth — no hace falta PROPFIND/MKCOL
/// porque el adaptador nunca los dispara para un path sin subcarpetas
/// (confirmado leyendo el código fuente de `webdav_client_plus`).
class _FakeWebDavServer {
  final HttpServer _server;
  Uint8List? storedBytes;

  _FakeWebDavServer._(this._server) {
    _server.listen(_handle);
  }

  static Future<_FakeWebDavServer> start() async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    return _FakeWebDavServer._(server);
  }

  String get url => 'http://${_server.address.address}:${_server.port}';

  Future<void> close() => _server.close(force: true);

  Future<void> _handle(HttpRequest request) async {
    final expectedAuth =
        'Basic ${base64Encode(utf8.encode('$_username:$_password'))}';
    if (request.headers.value(HttpHeaders.authorizationHeader) !=
        expectedAuth) {
      request.response.statusCode = HttpStatus.unauthorized;
      await request.response.close();
      return;
    }

    if (request.uri.path != _remotePath) {
      request.response.statusCode = HttpStatus.notFound;
      await request.response.close();
      return;
    }

    switch (request.method) {
      case 'HEAD':
        request.response.statusCode = storedBytes != null
            ? HttpStatus.ok
            : HttpStatus.notFound;
      case 'GET':
        if (storedBytes == null) {
          request.response.statusCode = HttpStatus.notFound;
        } else {
          request.response.statusCode = HttpStatus.ok;
          request.response.add(storedBytes!);
        }
      case 'PUT':
        final bytes = await request
            .fold<BytesBuilder>(BytesBuilder(), (b, chunk) => b..add(chunk))
            .then((b) => b.toBytes());
        storedBytes = bytes;
        request.response.statusCode = HttpStatus.created;
      default:
        request.response.statusCode = HttpStatus.methodNotAllowed;
    }
    await request.response.close();
  }
}

VaultFile _sampleFile(List<int> payload) {
  return VaultFile(
    header: VaultHeader(
      formatVersion: 1,
      formatMinReaderVersion: 1,
      salt: Uint8List.fromList(List.filled(16, 1)),
      nonce: Uint8List.fromList(List.filled(24, 2)),
      vaultId: 'vault-1',
      createdAt: DateTime.utc(2026, 1, 1),
      kdfParams: const Argon2Params(
        memoryKib: 262144,
        iterations: 3,
        parallelism: 1,
      ),
    ),
    encryptedPayload: Uint8List.fromList(payload),
  );
}

void main() {
  late _FakeWebDavServer server;

  setUp(() async {
    server = await _FakeWebDavServer.start();
  });

  tearDown(() => server.close());

  WebDavCredentials credentials() => WebDavCredentials(
    serverUrl: server.url,
    username: _username,
    password: _password,
  );

  group('WebdavSyncAdapter', () {
    test('remoteVaultExists() es false antes de subir nada', () async {
      final adapter = WebdavSyncAdapter(credentials());
      expect(await adapter.remoteVaultExists(), isFalse);
    });

    test(
      'upload + remoteVaultExists() + download: round-trip real por HTTP',
      () async {
        final adapter = WebdavSyncAdapter(credentials());
        final file = _sampleFile([10, 20, 30]);

        await adapter.uploadVault(file);

        expect(await adapter.remoteVaultExists(), isTrue);

        final downloaded = await adapter.downloadVault();
        expect(downloaded.header.vaultId, file.header.vaultId);
        expect(downloaded.encryptedPayload, file.encryptedPayload);
      },
    );

    test('credenciales incorrectas → error, no se sube nada', () async {
      final wrongCredentials = WebDavCredentials(
        serverUrl: server.url,
        username: _username,
        password: 'contraseña-equivocada',
      );
      final adapter = WebdavSyncAdapter(wrongCredentials);

      await expectLater(
        adapter.uploadVault(_sampleFile([1])),
        throwsA(anything),
      );
      expect(server.storedBytes, isNull);
    });
  });
}
