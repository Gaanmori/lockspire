// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Lockspire

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../design/lockspire_spacing.dart';
import '../vault_session_controller.dart';

class UnlockVaultScreen extends ConsumerStatefulWidget {
  const UnlockVaultScreen({super.key});

  @override
  ConsumerState<UnlockVaultScreen> createState() => _UnlockVaultScreenState();
}

class _UnlockVaultScreenState extends ConsumerState<UnlockVaultScreen> {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  bool _obscure = true;

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    await ref
        .read(vaultSessionControllerProvider.notifier)
        .unlock(_passwordController.text);
  }

  @override
  Widget build(BuildContext context) {
    final sessionState = ref.watch(vaultSessionControllerProvider);
    final isLoading = sessionState.isLoading;

    return Scaffold(
      appBar: AppBar(title: const Text('Lockspire')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: Padding(
            padding: const EdgeInsets.all(LockspireSpacing.lg),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: _passwordController,
                    obscureText: _obscure,
                    autofocus: true,
                    enabled: !isLoading,
                    decoration: InputDecoration(
                      labelText: 'Contraseña maestra',
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscure ? Icons.visibility : Icons.visibility_off,
                        ),
                        onPressed: () => setState(() => _obscure = !_obscure),
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Ingresá tu contraseña maestra';
                      }
                      return null;
                    },
                    onFieldSubmitted: (_) => isLoading ? null : _submit(),
                  ),
                  const SizedBox(height: LockspireSpacing.lg),
                  if (isLoading)
                    Padding(
                      padding: const EdgeInsets.only(bottom: LockspireSpacing.md),
                      child: Column(
                        children: [
                          const CircularProgressIndicator(),
                          const SizedBox(height: LockspireSpacing.smMd),
                          const Text(
                            'Desbloqueando… esto puede tardar unos segundos '
                            '(derivación de clave Argon2id)',
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    )
                  else if (sessionState.hasError)
                    Padding(
                      padding: const EdgeInsets.only(bottom: LockspireSpacing.md),
                      child: Text(
                        'Contraseña incorrecta',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  if (!isLoading)
                    FilledButton(
                      onPressed: _submit,
                      child: const Text('Desbloquear'),
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
