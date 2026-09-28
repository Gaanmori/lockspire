// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Lockspire

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lockspire/shared/platform_capabilities.dart';

import '../../../../design/lockspire_spacing.dart';
import '../providers/biometric_auth_port_provider.dart';
import '../providers/check_master_password_required_provider.dart';
import '../providers/vault_auth_attempt_provider.dart';
import '../vault_session_controller.dart';
import '../widgets/auth_card.dart';

class UnlockVaultScreen extends ConsumerStatefulWidget {
  const UnlockVaultScreen({super.key});

  @override
  ConsumerState<UnlockVaultScreen> createState() => _UnlockVaultScreenState();
}

class _UnlockVaultScreenState extends ConsumerState<UnlockVaultScreen> {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  bool _obscure = true;

  // Se consulta una sola vez al abrir la pantalla — si el usuario activa
  // o desactiva el desbloqueo biométrico desde "Seguridad", esta
  // pantalla ya se habrá recreado (bloqueo/desbloqueo de por medio) para
  // cuando vuelva a importar.
  bool _biometricAvailable = false;

  /// La biometría está activa, pero venció el plazo y toca escribir la
  /// contraseña maestra (ADR 0017).
  bool _passwordRequiredByReminder = false;

  @override
  void initState() {
    super.initState();
    _checkBiometricAvailability();
  }

  /// Si hay una clave biométrica guardada, muestra el botón **y** dispara
  /// el prompt de una vez — pedido explícito del usuario, para no tener
  /// que tocar "Usar huella" cada vez que se bloquea la bóveda. Si la
  /// huella falla o se cancela, [VaultSessionController.unlockWithBiometrics]
  /// no toca el estado (ver su doc comment) — la pantalla sigue mostrando
  /// el campo de contraseña normal, listo para escribir, sin ningún error
  /// que el usuario no pidió ver.
  ///
  /// Si venció el plazo de ADR 0017, no ofrece la biometría y explica por
  /// qué se pide la contraseña.
  Future<void> _checkBiometricAvailability() async {
    final port = ref.read(biometricAuthPortProvider);
    final hasStoredKey = await port.hasStoredKey();
    if (!mounted || !hasStoredKey) return;
    final required = await ref.read(checkMasterPasswordRequiredProvider)();
    if (!mounted) return;
    if (required) {
      setState(() => _passwordRequiredByReminder = true);
      return;
    }
    setState(() => _biometricAvailable = true);
    // Al pasar a segundo plano la bóveda se bloquea (ADR 0008) y esta
    // pantalla aparece con la app todavía en segundo plano. Android no puede
    // mostrar el diálogo de huella así, y local_auth quedaba con una
    // autenticación "en curso" trabada: los toques siguientes en "Usar la
    // huella" no hacían nada hasta reiniciar la app. Por eso, si no está en
    // primer plano, se espera a que vuelva.
    if (WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed) {
      await _submitWithBiometrics();
    } else {
      _promptWhenResumed = AppLifecycleListener(
        onResume: () {
          _promptWhenResumed?.dispose();
          _promptWhenResumed = null;
          if (mounted) _submitWithBiometrics();
        },
      );
    }
  }

  AppLifecycleListener? _promptWhenResumed;

  @override
  void dispose() {
    _promptWhenResumed?.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    await ref
        .read(vaultSessionControllerProvider.notifier)
        .unlock(_passwordController.text);
  }

  Future<void> _submitWithBiometrics() async {
    await ref
        .read(vaultSessionControllerProvider.notifier)
        .unlockWithBiometrics();
  }

  @override
  Widget build(BuildContext context) {
    // El progreso/error del intento vive en vaultAuthAttemptProvider, no en
    // vaultSessionControllerProvider — ver el comentario de ese provider.
    final attempt = ref.watch(vaultAuthAttemptProvider);
    final isLoading = attempt.isLoading;

    return Scaffold(
      appBar: AppBar(title: const Text('Lockspire')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(LockspireSpacing.lg),
            child: Form(
              key: _formKey,
              child: AuthCard(
                icon: Icons.lock_outline,
                title: '¡Hola de nuevo!',
                subtitle: 'Ingrese su contraseña para entrar a su bóveda',
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_passwordRequiredByReminder) ...[
                      Text(
                        'Por seguridad, cada tanto Lockspire le pide la '
                        'contraseña maestra aunque use '
                        '${ref.watch(platformCapabilitiesProvider).biometricMethodName}, '
                        'para que no se le olvide. Después vuelve a '
                        'funcionar como siempre.',
                        style: Theme.of(context).textTheme.bodySmall,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: LockspireSpacing.md),
                    ],
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
                          return 'Ingrese su contraseña maestra';
                        }
                        return null;
                      },
                      onFieldSubmitted: (_) => isLoading ? null : _submit(),
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
                              'Desbloqueando… esto puede tardar unos segundos '
                              '(derivación de clave Argon2id)',
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
                          'Contraseña incorrecta',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    if (!isLoading)
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: _submit,
                          child: const Text('Desbloquear'),
                        ),
                      ),
                    if (!isLoading && _biometricAvailable) ...[
                      const SizedBox(height: LockspireSpacing.sm),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: _submitWithBiometrics,
                          icon: const Icon(Icons.fingerprint),
                          label: Text(
                            'Usar ${ref.watch(platformCapabilitiesProvider).biometricMethodName}',
                          ),
                        ),
                      ),
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
