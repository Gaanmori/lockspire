// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Lockspire

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:lockspire/features/browser_bridge/application/handle_bridge_request.dart';
import 'package:lockspire/features/vault/domain/entities/vault.dart';
import 'package:lockspire/features/vault/domain/entities/vault_entry.dart';
import 'package:lockspire_bridge/lockspire_bridge.dart';

final _github = VaultEntry.create(
  title: 'GitHub',
  fields: {
    'username': 'ana',
    'password': 'pw-github',
    'url': 'https://github.com',
  },
);
final _githubWork = VaultEntry.create(
  title: 'github trabajo',
  fields: {
    'username': 'ana@empresa',
    'password': 'pw-work',
    'url': 'github.com',
  },
);
final _bank = VaultEntry.create(
  title: 'Banco',
  fields: {
    'username': 'ana',
    'password': 'pw-bank',
    'url': 'https://banco.example',
  },
);

void main() {
  Vault? vault;
  var showCalls = 0;
  final linkRequests = <LinkRequest>[];

  late HandleBridgeRequest handle;

  setUp(() {
    linkRequests.clear();
    vault = Vault(
      vaultId: 'test',
      schemaVersion: 1,
      entries: [_bank, _github, _githubWork],
    );
    showCalls = 0;
    handle = HandleBridgeRequest(
      currentVault: () => vault,
      showApp: () => showCalls++,
      generatePassword: (length) => 'x' * length,
      requestLink: linkRequests.add,
    );
  });

  group('vincular un sitio (ADR 0015)', () {
    test('LIST_CREDENTIALS devuelve todas, ordenadas y sin contraseñas', () {
      final response = handle(const ListCredentialsRequest('a'));
      final titles = (response['entries'] as List).map(
        (e) => (e as Map)['title'],
      );
      expect(titles, ['Banco', 'GitHub', 'github trabajo']);
      expect(jsonEncode(response), isNot(contains('pw-')));
    });

    test('LIST_CREDENTIALS con la bóveda bloqueada pide desbloquear', () {
      vault = null;
      expect(
        handle(const ListCredentialsRequest('a')),
        unlockRequiredResponse('a'),
      );
    });

    test('REQUEST_LINK_ORIGIN no toca la bóveda: solo pide confirmación '
        'en la app, con la URL sin www.', () {
      final before = vault!.entries.map((e) => e.fields['url']).toList();
      expect(
        handle(
          RequestLinkOriginRequest(
            'a',
            origin: 'https://www.facebook.com',
            entryId: _bank.id,
          ),
        ),
        okResponse('a'),
      );
      expect(vault!.entries.map((e) => e.fields['url']).toList(), before);
      final request = linkRequests.single;
      expect(request.entryId, _bank.id);
      expect(request.entryTitle, 'Banco');
      expect(request.currentUrl, 'https://banco.example');
      expect(request.newUrl, 'https://facebook.com');
    });

    test('REQUEST_LINK_ORIGIN de una entrada inexistente → NOT_FOUND, sin '
        'pedir nada', () {
      expect(
        handle(
          const RequestLinkOriginRequest(
            'a',
            origin: 'https://www.facebook.com',
            entryId: 'no-existe',
          ),
        ),
        errorResponse('a', ErrorCode.notFound),
      );
      expect(linkRequests, isEmpty);
    });
  });

  test('PING informa si la bóveda está bloqueada', () {
    expect(handle(const PingRequest('a'))['locked'], isFalse);
    vault = null;
    expect(handle(const PingRequest('a'))['locked'], isTrue);
  });

  test('con la bóveda bloqueada, las credenciales piden desbloquear', () {
    vault = null;
    expect(
      handle(const GetCredentialsRequest('a', origin: 'https://github.com')),
      unlockRequiredResponse('a'),
    );
    expect(
      handle(
        GetCredentialSecretRequest(
          'b',
          origin: 'https://github.com',
          entryId: _github.id,
        ),
      ),
      unlockRequiredResponse('b'),
    );
  });

  test('CREDENTIALS: solo las del origen, ordenadas y sin contraseñas', () {
    final response = handle(
      const GetCredentialsRequest('a', origin: 'https://github.com'),
    );
    expect(response['type'], MessageType.credentials);
    final entries = response['entries'] as List;
    expect(entries.map((e) => (e as Map)['title']), [
      'GitHub',
      'github trabajo',
    ]);
    expect(jsonEncode(response), isNot(contains('pw-')));
  });

  test('CREDENTIAL_SECRET devuelve la contraseña de la entrada pedida', () {
    expect(
      handle(
        GetCredentialSecretRequest(
          'a',
          origin: 'https://github.com',
          entryId: _githubWork.id,
        ),
      ),
      credentialSecretResponse(
        'a',
        username: 'ana@empresa',
        password: 'pw-work',
      ),
    );
  });

  test('CREDENTIAL_SECRET de una entrada de otro sitio → NOT_FOUND (igual '
      'que un id inexistente)', () {
    expect(
      handle(
        GetCredentialSecretRequest(
          'a',
          origin: 'https://github.com',
          entryId: _bank.id,
        ),
      ),
      errorResponse('a', ErrorCode.notFound),
    );
    expect(
      handle(
        const GetCredentialSecretRequest(
          'b',
          origin: 'https://github.com',
          entryId: 'no-existe',
        ),
      ),
      errorResponse('b', ErrorCode.notFound),
    );
  });

  test('GENERATE_PASSWORD no necesita la bóveda desbloqueada', () {
    vault = null;
    expect(
      handle(const GeneratePasswordRequest('a', length: 20)),
      generatedPasswordResponse('a', 'x' * 20),
    );
  });

  test('SHOW_APP trae la ventana al frente', () {
    expect(handle(const ShowAppRequest('a')), okResponse('a'));
    expect(showCalls, 1);
  });
}
