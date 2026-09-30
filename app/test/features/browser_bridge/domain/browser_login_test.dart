// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Gabriel Ángel Montoya Rico

import 'package:flutter_test/flutter_test.dart';
import 'package:lockspire/features/browser_bridge/domain/browser_login.dart';
import 'package:lockspire/features/vault/domain/entities/vault.dart';

import '../../../support/builders.dart';

/// Qué ofrecer al ver un inicio de sesión en el navegador (ADR 0034).
void main() {
  const login = BrowserLogin(
    origin: 'https://www.banco.example',
    username: 'ana',
    password: 'nueva',
  );

  Vault vaultWith(List<({String user, String password, String url})> rows) =>
      Vault(
        vaultId: 'v',
        schemaVersion: 1,
        entries: [
          for (final (i, r) in rows.indexed)
            anEntry(
              id: 'e$i',
              title: 'Entrada $i',
              username: r.user,
              password: r.password,
              url: r.url,
              modifiedAt: DateTime.utc(2026, 1, 1 + i),
            ),
        ],
      );

  test('el sitio se guarda sin "www." y la entrada queda vinculada', () {
    expect(login.site, 'banco.example');
    expect(login.newEntryFields['url'], 'https://banco.example');
    expect(
      const BrowserLogin(
        origin: 'https://x.example',
        username: '',
        password: 'p',
      ).newEntryFields.containsKey('username'),
      isFalse,
    );
  });

  test('otro sitio con el mismo usuario no cuenta: es nuevo', () {
    final vault = vaultWith([
      (user: 'ana', password: 'vieja', url: 'https://otro.example'),
    ]);

    expect(matchLogin(vault, login), isA<NewLogin>());
  });

  test('con dos entradas del mismo usuario se actualiza la más reciente', () {
    final vault = vaultWith([
      (user: 'ana', password: 'a', url: 'https://banco.example'),
      (user: 'ana', password: 'b', url: 'https://banco.example'),
    ]);

    final match = matchLogin(vault, login) as ChangedPassword;
    expect(match.entry.id, 'e1');
  });

  test('si alguna ya tiene esa contraseña, no se pregunta', () {
    final vault = vaultWith([
      (user: 'ana', password: 'a', url: 'https://banco.example'),
      (user: 'Ana', password: 'nueva', url: 'https://banco.example'),
    ]);

    expect(matchLogin(vault, login), isA<AlreadySaved>());
  });
}
