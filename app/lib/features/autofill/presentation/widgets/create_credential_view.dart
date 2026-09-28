// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Lockspire

import 'package:flutter/material.dart';
import '../../../../design/lockspire_spacing.dart';

/// Guardar en la bóveda una cuenta que se acaba de usar en otra app
/// (ADR 0011): nunca se guarda sola, el usuario confirma.
class CreateCredentialView extends StatelessWidget {
  final String packageName;
  final String? origin;
  final String username;
  final String password;
  final Future<void> Function({
    required String packageName,
    required String? origin,
    required String username,
    required String password,
  })
  onSave;
  final VoidCallback onDismiss;

  const CreateCredentialView({
    super.key,
    required this.packageName,
    required this.origin,
    required this.username,
    required this.password,
    required this.onSave,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(LockspireSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '¿Guardar esta credencial en Lockspire?',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: LockspireSpacing.sm),
            Text(
              '${origin != null ? Uri.parse(origin!).host : packageName} — '
              '$username',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: LockspireSpacing.lg),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => onSave(
                  packageName: packageName,
                  origin: origin,
                  username: username,
                  password: password,
                ),
                child: const Text('Guardar'),
              ),
            ),
            const SizedBox(height: LockspireSpacing.sm),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: onDismiss,
                child: const Text('No, gracias'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
