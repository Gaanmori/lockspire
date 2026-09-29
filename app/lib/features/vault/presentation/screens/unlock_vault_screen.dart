// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Gabriel Ángel Montoya Rico

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lockspire/shared/platform_capabilities.dart';

import '../../../../design/lockspire_spacing.dart';
import '../../application/change_master_password_use_case.dart'
    show IncorrectMasterPasswordException;
import '../../application/password_changed_elsewhere_port.dart';
import '../providers/biometric_auth_port_provider.dart';
import '../providers/check_master_password_required_provider.dart';
import '../providers/password_changed_elsewhere_port_provider.dart';
import '../providers/vault_auth_attempt_provider.dart';
import '../vault_session_controller.dart';
import '../widgets/auth_card.dart';

class UnlockVaultScreen extends ConsumerStatefulWidget {
  /// Mirar la nube por si la contraseña cambió en otro dispositivo (ADR
  /// 0024). El autocompletado lo apaga: rellenar no necesita la nube, y
  /// descargar la bóveda en cada relleno solo gasta datos y tiempo.
  final bool checkCloudForPasswordChange;

  const UnlockVaultScreen({super.key, this.checkCloudForPasswordChange = true});

  @override
  ConsumerState<UnlockVaultScreen> createState() => _UnlockVaultScreenState();
}

class _UnlockVaultScreenState extends ConsumerState<UnlockVaultScreen> {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  final _previousPasswordController = TextEditingController();
  bool _obscure = true;

  /// La contraseña maestra se cambió en otro dispositivo (ADR 0024): se
  /// pide la nueva, sin biometría.
  bool _changedElsewhere = false;

  /// El usuario eligió entrar con la contraseña anterior ("No tengo la
  /// contraseña nueva"). Sigue sin biometría.
  bool _usePreviousInstead = false;

  /// Hay cambios locales sin sincronizar: hace falta también la anterior.
  bool _needsPrevious = false;

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
    _start();
  }

  /// Primero lo ya sabido (sin red): si la contraseña cambió en otro
  /// dispositivo, no se ofrece la biometría. Después se mira la nube en
  /// segundo plano, sin demorar la huella de cada día.
  Future<void> _start() async {
    PasswordChangedElsewherePort? port;
    try {
      final ready = await ref.read(passwordChangedElsewherePortProvider.future);
      port = ready;
      if (await ready.isPending()) {
        if (mounted) setState(() => _changedElsewhere = true);
        return;
      }
    } catch (_) {
      // Sin sync o sin almacenamiento: desbloqueo normal.
    }
    if (!mounted) return;
    await _checkBiometricAvailability();
    if (port == null || !widget.checkCloudForPasswordChange) return;
    if (!await port.checkRemote() || !mounted) return;
    _promptWhenResumed?.dispose();
    _promptWhenResumed = null;
    setState(() {
      _changedElsewhere = true;
      _biometricAvailable = false;
    });
  }

  bool get _askNewPassword => _changedElsewhere && !_usePreviousInstead;

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
    _previousPasswordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final session = ref.read(vaultSessionControllerProvider.notifier);
    if (!_askNewPassword) {
      await session.unlock(_passwordController.text);
      return;
    }
    await session.unlockWithNewPassword(
      newPassword: _passwordController.text,
      previousPassword: _needsPrevious
          ? _previousPasswordController.text
          : null,
    );
    if (!mounted) return;
    if (ref.read(vaultAuthAttemptProvider).error
        is PreviousPasswordRequiredException) {
      setState(() => _needsPrevious = true);
    }
  }

  String _errorText(Object? error) => switch (error) {
    PreviousPasswordRequiredException() =>
      'Este dispositivo tiene cambios que aún no se sincronizaron. Para '
          'conservarlos, ingrese también la contraseña anterior.',
    IncorrectPreviousPasswordException() =>
      'La contraseña anterior no es correcta',
    IncorrectMasterPasswordException() when _askNewPassword =>
      'No es la contraseña nueva',
    _ when _askNewPassword => 'No se pudo completar: $error',
    _ => 'Contraseña incorrecta',
  };

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
                brand: true,
                title: '¡Hola de nuevo!',
                subtitle: 'Ingrese su contraseña para entrar a su bóveda',
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_askNewPassword) ...[
                      Text(
                        'La contraseña maestra se cambió en otro '
                        'dispositivo. Ingrese la nueva para entrar. Hasta '
                        'entonces no se puede usar '
                        '${ref.watch(platformCapabilitiesProvider).biometricMethodName}.',
                        style: Theme.of(context).textTheme.bodySmall,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: LockspireSpacing.md),
                    ] else if (_passwordRequiredByReminder) ...[
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
                        labelText: _askNewPassword
                            ? 'Contraseña maestra nueva'
                            : 'Contraseña maestra',
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
                    if (_askNewPassword && _needsPrevious) ...[
                      const SizedBox(height: LockspireSpacing.md),
                      TextFormField(
                        controller: _previousPasswordController,
                        obscureText: _obscure,
                        enabled: !isLoading,
                        decoration: const InputDecoration(
                          labelText: 'Contraseña anterior',
                        ),
                        validator: (value) => value == null || value.isEmpty
                            ? 'Ingrese la contraseña anterior'
                            : null,
                        onFieldSubmitted: (_) => isLoading ? null : _submit(),
                      ),
                    ],
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
                          _errorText(attempt.error),
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
                    if (!isLoading && _changedElsewhere) ...[
                      const SizedBox(height: LockspireSpacing.sm),
                      TextButton(
                        onPressed: () => setState(() {
                          _usePreviousInstead = !_usePreviousInstead;
                          _needsPrevious = false;
                          ref.read(vaultAuthAttemptProvider.notifier).state =
                              const AsyncData(null);
                        }),
                        child: Text(
                          _usePreviousInstead
                              ? 'Ingresar la contraseña nueva'
                              : 'No tengo la contraseña nueva',
                        ),
                      ),
                    ],
                    if (!isLoading &&
                        _biometricAvailable &&
                        !_changedElsewhere) ...[
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
