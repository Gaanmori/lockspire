// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Gabriel Ángel Montoya Rico

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:lockspire/features/appearance/domain/appearance_preference.dart';
import 'package:lockspire/features/browser_bridge/application/handle_bridge_request.dart';
import 'package:lockspire/features/browser_bridge/domain/browser_login.dart';
import 'package:lockspire/features/vault/domain/entities/vault.dart';
import 'package:lockspire/features/vault/domain/entities/vault_entry.dart';
import 'package:lockspire_bridge/lockspire_bridge.dart';

import '../../../support/fakes/fake_login_save_exclusions.dart';

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

  final saved = <(BrowserLogin, LoginMatch)>[];
  final afterUnlock = <BrowserLogin>[];
  late FakeLoginSaveExclusions exclusions;

  late HandleBridgeRequest handle;

  /// El despachador con los cuatro temas (A11), sobre los mismos dobles.
  HandleBridgeRequest build({
    AppearancePreference Function()? appearance,
    String? Function()? language,
  }) => HandleBridgeRequest(
    app: BridgeAppRequests(
      isLocked: () => vault == null,
      showApp: () => showCalls++,
      generatePassword: (length) => 'x' * length,
      currentAppearance: appearance ?? () => AppearancePreference.defaults,
      currentLanguage: language ?? () => null,
    ),
    credentials: BridgeCredentialRequests(currentVault: () => vault),
    links: BridgeLinkRequests(
      currentVault: () => vault,
      requestLink: linkRequests.add,
    ),
    logins: BridgeLoginSaveRequests(
      currentVault: () => vault,
      saveLogin: (login, match) async => saved.add((login, match)),
      saveAfterUnlock: afterUnlock.add,
      exclusions: exclusions,
    ),
  );

  setUp(() {
    linkRequests.clear();
    saved.clear();
    afterUnlock.clear();
    exclusions = FakeLoginSaveExclusions();
    vault = Vault(
      vaultId: 'test',
      schemaVersion: 1,
      entries: [_bank, _github, _githubWork],
    );
    showCalls = 0;
    handle = build();
  });

  group('vincular un sitio (ADR 0015)', () {
    test(
      'LIST_CREDENTIALS devuelve todas, ordenadas y sin contraseñas',
      () async {
        final response = await handle(const ListCredentialsRequest('a'));
        final titles = (response['entries'] as List).map(
          (e) => (e as Map)['title'],
        );
        expect(titles, ['Banco', 'GitHub', 'github trabajo']);
        expect(jsonEncode(response), isNot(contains('pw-')));
      },
    );

    test('LIST_CREDENTIALS con la bóveda bloqueada pide desbloquear', () async {
      vault = null;
      expect(
        await handle(const ListCredentialsRequest('a')),
        unlockRequiredResponse('a'),
      );
    });

    test('REQUEST_LINK_ORIGIN no toca la bóveda: solo pide confirmación '
        'en la app, con la URL sin www.', () async {
      final before = vault!.entries.map((e) => e.fields['url']).toList();
      expect(
        await handle(
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
        'pedir nada', () async {
      expect(
        await handle(
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

  test(
    'PING incluye el tema de la app para que la extensión lo siga',
    () async {
      final themed = build(
        appearance: () => const AppearancePreference(
          family: ThemeFamilyId.mint,
          mode: AppearanceMode.dark,
        ),
      );
      expect((await themed(const PingRequest('a')))['theme'], {
        'family': 'mint',
        'mode': 'dark',
      });
    },
  );

  test(
    'PING incluye el idioma de la app para que la extensión lo siga',
    () async {
      final localized = build(language: () => 'en');
      expect((await localized(const PingRequest('a')))['lang'], 'en');
      expect(
        (await handle(const PingRequest('a'))).containsKey('lang'),
        isFalse,
      );
    },
  );

  test('PING informa si la bóveda está bloqueada', () async {
    expect((await handle(const PingRequest('a')))['locked'], isFalse);
    vault = null;
    expect((await handle(const PingRequest('a')))['locked'], isTrue);
  });

  test('con la bóveda bloqueada, las credenciales piden desbloquear', () async {
    vault = null;
    expect(
      await handle(
        const GetCredentialsRequest('a', origin: 'https://github.com'),
      ),
      unlockRequiredResponse('a'),
    );
    expect(
      await handle(
        GetCredentialSecretRequest(
          'b',
          origin: 'https://github.com',
          entryId: _github.id,
        ),
      ),
      unlockRequiredResponse('b'),
    );
  });

  test(
    'CREDENTIALS: solo las del origen, ordenadas y sin contraseñas',
    () async {
      final response = await handle(
        const GetCredentialsRequest('a', origin: 'https://github.com'),
      );
      expect(response['type'], MessageType.credentials);
      final entries = response['entries'] as List;
      expect(entries.map((e) => (e as Map)['title']), [
        'GitHub',
        'github trabajo',
      ]);
      expect(jsonEncode(response), isNot(contains('pw-')));
    },
  );

  test(
    'CREDENTIAL_SECRET devuelve la contraseña de la entrada pedida',
    () async {
      expect(
        await handle(
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
    },
  );

  test('CREDENTIAL_SECRET de una entrada de otro sitio → NOT_FOUND (igual '
      'que un id inexistente)', () async {
    expect(
      await handle(
        GetCredentialSecretRequest(
          'a',
          origin: 'https://github.com',
          entryId: _bank.id,
        ),
      ),
      errorResponse('a', ErrorCode.notFound),
    );
    expect(
      await handle(
        const GetCredentialSecretRequest(
          'b',
          origin: 'https://github.com',
          entryId: 'no-existe',
        ),
      ),
      errorResponse('b', ErrorCode.notFound),
    );
  });

  test('GENERATE_PASSWORD no necesita la bóveda desbloqueada', () async {
    vault = null;
    expect(
      await handle(const GeneratePasswordRequest('a', length: 20)),
      generatedPasswordResponse('a', 'x' * 20),
    );
  });

  test('SHOW_APP trae la ventana al frente', () async {
    expect(await handle(const ShowAppRequest('a')), okResponse('a'));
    expect(showCalls, 1);
  });

  group('guardar inicios de sesión del navegador (ADR 0034)', () {
    CheckLoginRequest check(String user, String password) => CheckLoginRequest(
      'a',
      origin: 'https://www.banco.example',
      username: user,
      password: password,
    );

    test('un usuario nuevo en el sitio se ofrece guardar', () async {
      expect(
        await handle(check('otro', 'x')),
        loginStatusResponse('a', LoginStatus.newLogin),
      );
    });

    test('el mismo usuario con otra contraseña se ofrece actualizar, con el '
        'título de la entrada; sin distinguir mayúsculas', () async {
      expect(
        await handle(check(' ANA ', 'pw-nueva')),
        loginStatusResponse('a', LoginStatus.update, title: 'Banco'),
      );
    });

    test('lo que ya está guardado no se pregunta', () async {
      expect(
        await handle(check('ana', 'pw-bank')),
        loginStatusResponse('a', LoginStatus.saved),
      );
    });

    test('"nunca en este sitio" se respeta, también con la bóveda '
        'bloqueada', () async {
      expect(
        await handle(
          const NeverSaveForOriginRequest(
            'n',
            origin: 'https://www.banco.example',
          ),
        ),
        okResponse('n'),
      );
      expect(exclusions.sites, {'banco.example'});
      vault = null;
      expect(
        await handle(check('otro', 'x')),
        loginStatusResponse('a', LoginStatus.never),
      );
    });

    test('con la bóveda bloqueada, comprobar pide desbloquear', () async {
      vault = null;
      expect(await handle(check('ana', 'x')), unlockRequiredResponse('a'));
    });

    test('guardar pasa lo que hay que hacer: entrada nueva o contraseña '
        'nueva', () async {
      await handle(
        const SaveLoginRequest(
          'a',
          origin: 'https://banco.example',
          username: 'ana',
          password: 'pw-nueva',
        ),
      );
      await handle(
        const SaveLoginRequest(
          'b',
          origin: 'https://nuevo.example',
          username: 'ana',
          password: 'x',
        ),
      );

      expect(saved.map((s) => s.$2.runtimeType), [ChangedPassword, NewLogin]);
      expect((saved.first.$2 as ChangedPassword).entry.id, _bank.id);
      expect(saved.last.$1.newEntryFields, {
        'username': 'ana',
        'password': 'x',
        'url': 'https://nuevo.example',
      });
    });

    test('guardar algo ya guardado no cambia nada', () async {
      expect(
        await handle(
          const SaveLoginRequest(
            'a',
            origin: 'https://banco.example',
            username: 'ana',
            password: 'pw-bank',
          ),
        ),
        okResponse('a'),
      );
      expect(saved, isEmpty);
    });

    test('con la bóveda bloqueada, guardar queda para después de '
        'desbloquear', () async {
      vault = null;

      expect(
        await handle(
          const SaveLoginRequest(
            'a',
            origin: 'https://banco.example',
            username: 'ana',
            password: 'pw-nueva',
          ),
        ),
        unlockRequiredResponse('a'),
      );
      expect(afterUnlock.single.password, 'pw-nueva');
      expect(saved, isEmpty);
    });
  });
}
