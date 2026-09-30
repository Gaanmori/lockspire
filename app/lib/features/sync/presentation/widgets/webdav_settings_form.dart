// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Gabriel Ángel Montoya Rico

import 'package:flutter/material.dart';
import 'package:lockspire/design/lockspire_spacing.dart';
import 'package:lockspire/l10n/l10n.dart';

import '../../domain/ports/sync_credentials_port.dart';
import '../../domain/webdav_url_policy.dart';

/// Servidor, usuario y contraseña de WebDAV (revisión 2026-09-30, A15: antes
/// vivía en `SyncSettingsScreen`). Solo `https` (hallazgo S2).
class WebDavSettingsForm extends StatefulWidget {
  /// Las credenciales guardadas, o `null` si todavía no hay.
  final WebDavCredentials? saved;

  /// Guarda lo escrito. `false` si no se guardó (p. ej. el usuario no
  /// confirmó mudar la bóveda).
  final Future<bool> Function(WebDavCredentials credentials) onSave;

  const WebDavSettingsForm({
    super.key,
    required this.saved,
    required this.onSave,
  });

  @override
  State<WebDavSettingsForm> createState() => _WebDavSettingsFormState();
}

class _WebDavSettingsFormState extends State<WebDavSettingsForm> {
  final _formKey = GlobalKey<FormState>();

  // Se precargan una sola vez: un rebuild de la pantalla (p. ej. al
  // sincronizar) no debe pisar lo que el usuario está editando.
  late final _server = TextEditingController(text: widget.saved?.serverUrl);
  late final _username = TextEditingController(text: widget.saved?.username);
  final _password = TextEditingController();

  @override
  void dispose() {
    _server.dispose();
    _username.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    // Vacía al editar: se conserva la contraseña guardada.
    final saved = widget.saved;
    final password = _password.text.isEmpty && saved != null
        ? saved.password
        : _password.text;
    final done = await widget.onSave(
      WebDavCredentials(
        serverUrl: _server.text,
        username: _username.text,
        password: password,
      ),
    );
    if (done && mounted) _password.clear();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextFormField(
            controller: _server,
            decoration: InputDecoration(
              labelText: l10n.syncWebdavUrl,
              hintText: 'https://mi-servidor.ejemplo/dav',
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return l10n.syncWebdavUrlRequired;
              }
              return switch (checkWebDavUrl(value)) {
                null => null,
                WebDavUrlProblem.insecure => l10n.syncWebdavHttpsRequired,
                WebDavUrlProblem.invalid => l10n.syncWebdavUrlInvalid,
              };
            },
          ),
          const SizedBox(height: LockspireSpacing.md),
          TextFormField(
            controller: _username,
            decoration: InputDecoration(labelText: l10n.syncWebdavUser),
            validator: (value) => (value == null || value.isEmpty)
                ? l10n.syncWebdavUserRequired
                : null,
          ),
          const SizedBox(height: LockspireSpacing.md),
          TextFormField(
            controller: _password,
            obscureText: true,
            decoration: InputDecoration(
              labelText: l10n.syncWebdavPassword,
              hintText: widget.saved != null
                  ? l10n.syncWebdavPasswordUnchanged
                  : null,
            ),
            validator: (value) {
              if (widget.saved == null && (value == null || value.isEmpty)) {
                return l10n.syncWebdavPasswordRequired;
              }
              return null;
            },
          ),
          const SizedBox(height: LockspireSpacing.lg),
          FilledButton(onPressed: _save, child: Text(l10n.commonSave)),
        ],
      ),
    );
  }
}
