// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Lockspire

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lockspire/design/lockspire_spacing.dart';
import 'package:lockspire/features/vault/application/change_master_password_use_case.dart'
    show IncorrectMasterPasswordException;

import '../../application/sync_vault_use_case.dart';
import '../sync_controller.dart';

/// Aviso visible en toda la app cuando la última sync se rechazó porque la
/// contraseña maestra se cambió en otro dispositivo (ADR 0018). Sin ese
/// caso no ocupa espacio.
class PasswordChangedElsewhereBanner extends ConsumerWidget {
  const PasswordChangedElsewhereBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final error = ref.watch(syncControllerProvider).error;
    final changedElsewhere =
        error is RemoteVaultRejectedException &&
        error.reason == RemoteVaultRejection.passwordChanged;
    if (!changedElsewhere) return const SizedBox.shrink();

    return MaterialBanner(
      leading: const Icon(Icons.key_outlined),
      content: const Text(
        'La contraseña maestra se cambió en otro dispositivo. Ingrese la '
        'nueva para seguir sincronizando.',
      ),
      actions: [
        TextButton(
          onPressed: () => showDialog<void>(
            context: context,
            builder: (_) => const _AdoptRemotePasswordDialog(),
          ),
          child: const Text('Ingresar contraseña nueva'),
        ),
      ],
    );
  }
}

class _AdoptRemotePasswordDialog extends ConsumerStatefulWidget {
  const _AdoptRemotePasswordDialog();

  @override
  ConsumerState<_AdoptRemotePasswordDialog> createState() =>
      _AdoptRemotePasswordDialogState();
}

class _AdoptRemotePasswordDialogState
    extends ConsumerState<_AdoptRemotePasswordDialog> {
  final _controller = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_controller.text.isEmpty) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref
          .read(syncControllerProvider.notifier)
          .adoptRemoteMasterPassword(_controller.text);
      if (mounted) Navigator.of(context).pop();
    } on IncorrectMasterPasswordException {
      setState(() => _error = 'No es la contraseña nueva');
    } catch (error) {
      setState(() => _error = 'No se pudo completar: $error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Contraseña maestra nueva'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Ingrese la contraseña que puso en el otro dispositivo. Los '
            'cambios que hizo aquí se conservan.',
          ),
          const SizedBox(height: LockspireSpacing.md),
          TextField(
            controller: _controller,
            obscureText: true,
            autofocus: true,
            enabled: !_busy,
            decoration: InputDecoration(
              labelText: 'Contraseña nueva',
              errorText: _error,
            ),
            onSubmitted: (_) => _submit(),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _busy ? null : _submit,
          child: _busy
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Continuar'),
        ),
      ],
    );
  }
}
