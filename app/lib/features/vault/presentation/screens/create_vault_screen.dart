// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Lockspire

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../design/lockspire_spacing.dart';
import '../../application/master_password_policy.dart';
import '../providers/vault_auth_attempt_provider.dart';
import '../vault_session_controller.dart';
import '../widgets/auth_card.dart';

class CreateVaultScreen extends ConsumerStatefulWidget {
  /// Pantalla para restaurar una bóveda desde la nube. La inyecta la app
  /// (vive en `sync`, hallazgo A3); sin ella no se ofrece la opción.
  final WidgetBuilder? restoreVaultBuilder;

  const CreateVaultScreen({super.key, this.restoreVaultBuilder});

  @override
  ConsumerState<CreateVaultScreen> createState() => _CreateVaultScreenState();
}

class _CreateVaultScreenState extends ConsumerState<CreateVaultScreen> {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _obscure = true;

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    await ref
        .read(vaultSessionControllerProvider.notifier)
        .createVault(_passwordController.text);
  }

  @override
  Widget build(BuildContext context) {
    // El progreso/error del intento vive en vaultAuthAttemptProvider, no en
    // vaultSessionControllerProvider — ver el comentario de ese provider.
    final attempt = ref.watch(vaultAuthAttemptProvider);
    final isLoading = attempt.isLoading;

    return Scaffold(
      appBar: AppBar(title: const Text('Crear bóveda')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(LockspireSpacing.lg),
            child: Form(
              key: _formKey,
              child: AuthCard(
                icon: Icons.gpp_good_outlined,
                title: 'Creá tu bóveda',
                subtitle:
                    'Elegí una contraseña maestra. Nunca se envía ni se '
                    'guarda — si la olvidás, no hay forma de recuperarla.',
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: _passwordController,
                      obscureText: _obscure,
                      autofocus: true,
                      decoration: InputDecoration(
                        labelText: 'Contraseña maestra',
                        helperText:
                            'Mínimo $masterPasswordMinLength caracteres',
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscure ? Icons.visibility : Icons.visibility_off,
                          ),
                          onPressed: () => setState(() => _obscure = !_obscure),
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Ingresá una contraseña';
                        }
                        final problem = checkNewMasterPassword(value);
                        return problem == null
                            ? null
                            : describeMasterPasswordProblem(problem);
                      },
                    ),
                    const SizedBox(height: LockspireSpacing.md),
                    TextFormField(
                      controller: _confirmController,
                      obscureText: _obscure,
                      decoration: const InputDecoration(
                        labelText: 'Confirmar contraseña',
                      ),
                      validator: (value) {
                        if (value != _passwordController.text) {
                          return 'No coincide con la contraseña anterior';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: LockspireSpacing.lg),
                    if (isLoading)
                      Padding(
                        padding: const EdgeInsets.only(
                          bottom: LockspireSpacing.md,
                        ),
                        child: Column(
                          children: [
                            const ClipRRect(
                              borderRadius: BorderRadius.all(
                                Radius.circular(4),
                              ),
                              child: LinearProgressIndicator(),
                            ),
                            const SizedBox(height: LockspireSpacing.smMd),
                            const Text(
                              'Creando bóveda… esto puede tardar unos '
                              'segundos (derivación de clave Argon2id)',
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      )
                    else if (attempt.hasError)
                      Padding(
                        padding: const EdgeInsets.only(
                          bottom: LockspireSpacing.md,
                        ),
                        child: Text(
                          'No se pudo crear la bóveda: ${attempt.error}',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    if (!isLoading) ...[
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: _submit,
                          child: const Text('Crear bóveda'),
                        ),
                      ),
                      if (widget.restoreVaultBuilder case final restore?) ...[
                        const SizedBox(height: LockspireSpacing.md),
                        TextButton(
                          onPressed: () => Navigator.of(
                            context,
                          ).push(MaterialPageRoute(builder: restore)),
                          child: const Text(
                            '¿Ya tenés una bóveda? Restaurarla desde la nube',
                          ),
                        ),
                      ],
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
