// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Gabriel Ángel Montoya Rico

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../design/lockspire_spacing.dart';
import '../../application/master_password_policy.dart';
import '../providers/vault_auth_attempt_provider.dart';
import '../vault_session_controller.dart';
import '../widgets/auth_card.dart';
import '../widgets/headered_card.dart';
import 'package:lockspire/l10n/l10n.dart';
import 'package:lockspire/l10n/localized_error.dart';

class CreateVaultScreen extends ConsumerStatefulWidget {
  /// Pantalla para restaurar una bóveda desde la nube. La inyecta la app
  /// (vive en `sync`, hallazgo A3); sin ella no se ofrece la opción.
  final WidgetBuilder? restoreVaultBuilder;

  /// Ver `UnlockVaultScreen.header`.
  final Widget? header;

  const CreateVaultScreen({super.key, this.restoreVaultBuilder, this.header});

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
      appBar: AppBar(title: Text(context.l10n.createVaultTitle)),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(LockspireSpacing.lg),
            child: Form(
              key: _formKey,
              child: HeaderedCard(
                header: widget.header,
                card: AuthCard(
                  icon: Icons.gpp_good_outlined,
                  brand: true,
                  title: context.l10n.createVaultHeading,
                  subtitle: context.l10n.createVaultIntro,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(
                        controller: _passwordController,
                        obscureText: _obscure,
                        autofocus: true,
                        decoration: InputDecoration(
                          labelText: context.l10n.commonMasterPassword,
                          helperText: context.l10n.createVaultMinLength(
                            masterPasswordMinLength,
                          ),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscure
                                  ? Icons.visibility
                                  : Icons.visibility_off,
                            ),
                            onPressed: () =>
                                setState(() => _obscure = !_obscure),
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return context.l10n.createVaultPasswordRequired;
                          }
                          final problem = checkNewMasterPassword(value);
                          return problem == null
                              ? null
                              : localizeMasterPasswordProblem(
                                  context.l10n,
                                  problem,
                                );
                        },
                      ),
                      const SizedBox(height: LockspireSpacing.md),
                      TextFormField(
                        controller: _confirmController,
                        obscureText: _obscure,
                        decoration: InputDecoration(
                          labelText: context.l10n.createVaultConfirm,
                        ),
                        validator: (value) {
                          if (value != _passwordController.text) {
                            return context.l10n.createVaultMismatch;
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
                              Text(
                                context.l10n.createVaultCreating,
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
                            context.l10n.createVaultFailed(
                              localizeError(context.l10n, attempt.error!),
                            ),
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
                            child: Text(context.l10n.createVaultTitle),
                          ),
                        ),
                        if (widget.restoreVaultBuilder case final restore?) ...[
                          const SizedBox(height: LockspireSpacing.md),
                          TextButton(
                            onPressed: () => Navigator.of(
                              context,
                            ).push(MaterialPageRoute(builder: restore)),
                            child: Text(context.l10n.createVaultRestoreLink),
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
      ),
    );
  }
}
