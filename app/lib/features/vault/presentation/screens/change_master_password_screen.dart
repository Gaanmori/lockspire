// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Gabriel Ángel Montoya Rico

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../design/lockspire_spacing.dart';
import '../../application/change_master_password_use_case.dart';
import '../../application/master_password_policy.dart';
import '../../application/save_vault_use_case.dart';
import '../vault_session_controller.dart';
import 'package:lockspire/l10n/l10n.dart';
import 'package:lockspire/l10n/localized_error.dart';

/// Cambiar la contraseña maestra (ADR 0018). Pide la actual aunque la
/// bóveda esté desbloqueada.
class ChangeMasterPasswordScreen extends ConsumerStatefulWidget {
  const ChangeMasterPasswordScreen({super.key});

  @override
  ConsumerState<ChangeMasterPasswordScreen> createState() =>
      _ChangeMasterPasswordScreenState();
}

class _ChangeMasterPasswordScreenState
    extends ConsumerState<ChangeMasterPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _currentController = TextEditingController();
  final _newController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _obscure = true;
  bool _busy = false;
  String? _currentPasswordError;
  String? _error;

  @override
  void dispose() {
    _currentController.dispose();
    _newController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _currentPasswordError = null;
      _error = null;
    });
    if (!_formKey.currentState!.validate()) return;

    setState(() => _busy = true);
    try {
      await ref
          .read(vaultSessionControllerProvider.notifier)
          .changeMasterPassword(
            currentPassword: _currentController.text,
            newPassword: _newController.text,
          );
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.l10n.changePwDone)));
      Navigator.of(context).pop();
    } on IncorrectMasterPasswordException {
      setState(() => _currentPasswordError = context.l10n.changePwCurrentWrong);
    } on VaultWriteConflictException {
      setState(() => _error = context.l10n.changePwConflict);
    } catch (error) {
      setState(
        () => _error = context.l10n.changePwFailed(
          localizeError(context.l10n, error),
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _passwordField({
    required TextEditingController controller,
    required String label,
    String? helperText,
    String? errorText,
    bool autofocus = false,
    FormFieldValidator<String>? validator,
  }) => TextFormField(
    controller: controller,
    obscureText: _obscure,
    autofocus: autofocus,
    enabled: !_busy,
    decoration: InputDecoration(
      labelText: label,
      helperText: helperText,
      errorText: errorText,
    ),
    validator: validator,
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.changePwTitle)),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(LockspireSpacing.lg),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(context.l10n.changePwIntro),
                  const SizedBox(height: LockspireSpacing.lg),
                  _passwordField(
                    controller: _currentController,
                    label: context.l10n.changePwCurrent,
                    autofocus: true,
                    errorText: _currentPasswordError,
                    validator: (value) => (value == null || value.isEmpty)
                        ? context.l10n.changePwCurrentRequired
                        : null,
                  ),
                  const SizedBox(height: LockspireSpacing.md),
                  _passwordField(
                    controller: _newController,
                    label: context.l10n.pwChangedNewPassword,
                    helperText: context.l10n.changePwNewHelper(
                      masterPasswordMinLength,
                    ),
                    validator: (value) {
                      final problem = checkNewMasterPassword(value ?? '');
                      if (problem != null) {
                        return localizeMasterPasswordProblem(
                          context.l10n,
                          problem,
                        );
                      }
                      if (value == _currentController.text) {
                        return context.l10n.changePwMustDiffer;
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: LockspireSpacing.md),
                  _passwordField(
                    controller: _confirmController,
                    label: context.l10n.changePwConfirmNew,
                    validator: (value) => value != _newController.text
                        ? context.l10n.changePwMismatch
                        : null,
                  ),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(context.l10n.changePwShowPasswords),
                    value: !_obscure,
                    onChanged: _busy
                        ? null
                        : (value) =>
                              setState(() => _obscure = !(value ?? false)),
                  ),
                  if (_error != null) ...[
                    Text(
                      _error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                    const SizedBox(height: LockspireSpacing.md),
                  ],
                  FilledButton(
                    onPressed: _busy ? null : _submit,
                    child: _busy
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(context.l10n.changePwButton),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
