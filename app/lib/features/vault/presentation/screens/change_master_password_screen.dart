// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Lockspire

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../design/lockspire_spacing.dart';
import '../../application/change_master_password_use_case.dart';
import '../../application/master_password_policy.dart';
import '../../application/save_vault_use_case.dart';
import '../vault_session_controller.dart';

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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Contraseña maestra cambiada. Sus otros dispositivos se la '
            'pedirán la próxima vez que sincronicen.',
          ),
        ),
      );
      Navigator.of(context).pop();
    } on IncorrectMasterPasswordException {
      setState(
        () => _currentPasswordError = 'La contraseña actual no es correcta',
      );
    } on VaultWriteConflictException {
      setState(
        () => _error =
            'La bóveda cambió mientras se guardaba. La nube ya tiene la '
            'contraseña nueva: sincronice y, cuando se la pida, ingrésela.',
      );
    } catch (error) {
      setState(
        () => _error =
            'No se pudo cambiar la contraseña, así que sigue siendo la '
            'misma. $error',
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
      appBar: AppBar(title: const Text('Cambiar contraseña maestra')),
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
                  const Text(
                    'Si tiene sincronización, primero se sincroniza y la '
                    'bóveda nueva se sube a la nube: hace falta conexión. '
                    'Las copias viejas que alguien ya tenga siguen abriéndose '
                    'con la contraseña anterior.',
                  ),
                  const SizedBox(height: LockspireSpacing.lg),
                  _passwordField(
                    controller: _currentController,
                    label: 'Contraseña actual',
                    autofocus: true,
                    errorText: _currentPasswordError,
                    validator: (value) => (value == null || value.isEmpty)
                        ? 'Ingrese su contraseña actual'
                        : null,
                  ),
                  const SizedBox(height: LockspireSpacing.md),
                  _passwordField(
                    controller: _newController,
                    label: 'Contraseña nueva',
                    helperText:
                        'Mínimo $masterPasswordMinLength caracteres, difícil '
                        'de adivinar',
                    validator: (value) {
                      final problem = checkNewMasterPassword(value ?? '');
                      if (problem != null) {
                        return describeMasterPasswordProblem(problem);
                      }
                      if (value == _currentController.text) {
                        return 'Tiene que ser distinta de la actual';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: LockspireSpacing.md),
                  _passwordField(
                    controller: _confirmController,
                    label: 'Confirmar contraseña nueva',
                    validator: (value) => value != _newController.text
                        ? 'No coincide con la contraseña nueva'
                        : null,
                  ),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Mostrar contraseñas'),
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
                        : const Text('Cambiar contraseña'),
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
