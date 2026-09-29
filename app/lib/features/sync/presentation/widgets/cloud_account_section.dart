// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Gabriel Ángel Montoya Rico

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../design/lockspire_spacing.dart';

/// Estado de una cuenta de nube con login (Google Drive, OneDrive):
/// conectar si no hay cuenta, o "Conectado como …" y desconectar.
/// [account] es el correo de la cuenta conectada, o `null`.
class CloudAccountSection extends StatelessWidget {
  final AsyncValue<String?> account;

  /// A qué accede Lockspire en esa nube, para mostrar antes de conectar.
  final String scopeNote;
  final String connectLabel;
  final VoidCallback onConnect;
  final VoidCallback onDisconnect;

  const CloudAccountSection({
    super.key,
    required this.account,
    required this.scopeNote,
    required this.connectLabel,
    required this.onConnect,
    required this.onDisconnect,
  });

  @override
  Widget build(BuildContext context) {
    return account.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) =>
          Text('Ocurrió un error: $error', textAlign: TextAlign.center),
      data: (email) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: email == null
            ? [
                Text(
                  'Sin cuenta conectada. $scopeNote',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: LockspireSpacing.lg),
                FilledButton(onPressed: onConnect, child: Text(connectLabel)),
              ]
            : [
                Text('Conectado como $email', textAlign: TextAlign.center),
                const SizedBox(height: LockspireSpacing.lg),
                // Secundaria: desconectar no debería invitar a tocarla.
                TextButton(
                  onPressed: onDisconnect,
                  child: const Text('Desconectar'),
                ),
              ],
      ),
    );
  }
}
