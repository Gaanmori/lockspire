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

  late HandleBridgeRequest handle;

  setUp(() {
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
    );
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
