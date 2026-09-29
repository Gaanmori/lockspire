// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Gabriel Ángel Montoya Rico

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lockspire/design/lockspire_spacing.dart';
import 'package:lockspire/features/vault/application/change_master_password_use_case.dart'
    show IncorrectMasterPasswordException;

import '../../application/sync_vault_use_case.dart';
import '../sync_controller.dart';
import 'package:lockspire/l10n/l10n.dart';
import 'package:lockspire/l10n/localized_error.dart';
import 'package:lockspire/shared/presentation/navigation.dart';

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
      forceActionsBelow: true,
      leading: const Icon(Icons.key_outlined),
      content: Text(context.l10n.pwChangedBanner),
      actions: [
        TextButton(
          onPressed: () => showDialog<void>(
            context: context,
            builder: (_) => const _AdoptRemotePasswordDialog(),
          ),
          child: Text(context.l10n.pwChangedEnterNew),
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
      if (mounted) popIfCurrent(context);
    } on IncorrectMasterPasswordException {
      setState(() => _error = context.l10n.pwChangedNotNew);
    } catch (error) {
      setState(
        () => _error = context.l10n.commonCouldNotComplete(
          localizeError(context.l10n, error),
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(context.l10n.pwChangedDialogTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(context.l10n.pwChangedDialogBody),
          const SizedBox(height: LockspireSpacing.md),
          TextField(
            controller: _controller,
            obscureText: true,
            autofocus: true,
            enabled: !_busy,
            decoration: InputDecoration(
              labelText: context.l10n.pwChangedNewPassword,
              errorText: _error,
            ),
            onSubmitted: (_) => _submit(),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.of(context).pop(),
          child: Text(context.l10n.commonCancel),
        ),
        FilledButton(
          onPressed: _busy ? null : _submit,
          child: _busy
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(context.l10n.commonContinue),
        ),
      ],
    );
  }
}
