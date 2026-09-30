// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Gabriel Ángel Montoya Rico

import '../../vault/domain/entities/entry_fields.dart';
import '../../vault/domain/entities/vault.dart';
import '../../vault/domain/entities/vault_entry.dart';
import 'origin_matcher.dart';

/// Un inicio de sesión que la extensión vio enviar en una página (ADR
/// 0034). [origin] lo pone la extensión a partir de la pestaña, nunca la
/// página.
class BrowserLogin {
  final String origin;
  final String username;
  final String password;

  const BrowserLogin({
    required this.origin,
    required this.username,
    required this.password,
  });

  /// El sitio tal como se guarda y se muestra: el host, sin "www.".
  String get site => Uri.parse(linkedUrlForOrigin(origin)).host;

  /// La entrada nueva: título = el sitio, y la dirección vinculada al
  /// origen (la misma regla que al vincular desde la extensión, ADR 0015).
  Map<String, String> get newEntryFields => {
    if (username.isNotEmpty) EntryFields.username: username,
    EntryFields.password: password,
    EntryFields.url: linkedUrlForOrigin(origin),
  };
}

/// Qué es [BrowserLogin] respecto de la bóveda.
sealed class LoginMatch {
  const LoginMatch();
}

/// Ninguna entrada del sitio tiene ese usuario: se ofrece guardarlo.
class NewLogin extends LoginMatch {
  const NewLogin();
}

/// [entry] es del sitio y tiene ese usuario, con otra contraseña: se ofrece
/// actualizarla.
class ChangedPassword extends LoginMatch {
  final VaultEntry entry;
  const ChangedPassword(this.entry);
}

/// Ya está guardado tal cual: no se pregunta nada.
class AlreadySaved extends LoginMatch {
  const AlreadySaved();
}

/// Busca [login] entre las contraseñas del sitio. El usuario se compara sin
/// distinguir mayúsculas ni espacios de los extremos (los correos no las
/// distinguen). Con varias entradas del mismo usuario, se actualiza la
/// modificada más recientemente.
LoginMatch matchLogin(Vault vault, BrowserLogin login) {
  final forSite = vault.entries
      .where((e) => entryMatchesOrigin(e, login.origin))
      .toList();
  String norm(String s) => s.trim().toLowerCase();
  final sameUser = forSite
      .where(
        (e) =>
            norm(e.fields[EntryFields.username] ?? '') == norm(login.username),
      )
      .toList();
  if (sameUser.any((e) => e.fields[EntryFields.password] == login.password)) {
    return const AlreadySaved();
  }
  if (sameUser.isEmpty) return const NewLogin();
  sameUser.sort((a, b) => b.modifiedAt.compareTo(a.modifiedAt));
  return ChangedPassword(sameUser.first);
}
