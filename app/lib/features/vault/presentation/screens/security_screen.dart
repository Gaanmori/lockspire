// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Lockspire

import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../design/lockspire_spacing.dart';
import '../../domain/ports/biometric_auth_port.dart';
import '../providers/biometric_auth_port_provider.dart';
import '../vault_session_controller.dart';

const _settingsChannel = MethodChannel('com.lockspire.lockspire/settings');

/// Nombre del método biométrico según la plataforma — usado en los
/// textos de esta pantalla (ver docs/adr/0010-desbloqueo-biometrico.md,
/// alcance Android + Windows únicamente).
String get _biometricMethodName =>
    Platform.isWindows ? 'Windows Hello' : 'la huella';

/// Activar/desactivar el desbloqueo biométrico (ver `BiometricAuthPort`)
/// — accesible desde `vault_unlocked_screen.dart`. Sin `Riverpod`
/// provider dedicado para el estado activado/disponible a propósito:
/// alcance chico, esta es la única pantalla que lo necesita, así que un
/// `FutureBuilder` local re-consultado tras cada cambio alcanza sin
/// plumbing de invalidación extra.
class SecurityScreen extends ConsumerStatefulWidget {
  const SecurityScreen({super.key});

  @override
  ConsumerState<SecurityScreen> createState() => _SecurityScreenState();
}

class _SecurityScreenState extends ConsumerState<SecurityScreen> {
  late Future<(BiometricAvailability, bool)> _statusFuture;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _statusFuture = _loadStatus();
  }

  Future<(BiometricAvailability, bool)> _loadStatus() async {
    final port = ref.read(biometricAuthPortProvider);
    final availability = await port.checkAvailability();
    final enabled = await port.hasStoredKey();
    return (availability, enabled);
  }

  void _refresh() => setState(() => _statusFuture = _loadStatus());

  Future<void> _toggle(bool value) async {
    setState(() => _busy = true);
    final controller = ref.read(vaultSessionControllerProvider.notifier);
    if (value) {
      await controller.enableBiometricUnlock();
    } else {
      await controller.disableBiometricUnlock();
    }
    if (!mounted) return;
    setState(() => _busy = false);
    _refresh();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Seguridad')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(LockspireSpacing.lg),
          child: FutureBuilder<(BiometricAvailability, bool)>(
            future: _statusFuture,
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final (availability, enabled) = snapshot.data!;
              final available = availability == BiometricAvailability.available;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text('Desbloquear con $_biometricMethodName'),
                    subtitle: Text(
                      available
                          ? 'Usá $_biometricMethodName en vez de escribir la '
                                'contraseña maestra cada vez.'
                          : _unavailableReason(availability),
                    ),
                    value: enabled,
                    onChanged: (available && !_busy) ? _toggle : null,
                  ),
                  if (_busy) ...[
                    const SizedBox(height: LockspireSpacing.md),
                    const Center(child: CircularProgressIndicator()),
                  ],
                  if (Platform.isAndroid) ...[
                    const SizedBox(height: LockspireSpacing.lg),
                    const Divider(),
                    const SizedBox(height: LockspireSpacing.md),
                    Text(
                      'Autocompletado',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: LockspireSpacing.sm),
                    const Text(
                      'Activá Lockspire como gestor de credenciales del '
                      'sistema para que aparezca como opción al iniciar '
                      'sesión en otras apps (Android 14 o superior).',
                    ),
                    const SizedBox(height: LockspireSpacing.md),
                    OutlinedButton(
                      onPressed: () => _settingsChannel.invokeMethod(
                        'openCredentialProviderSettings',
                      ),
                      child: const Text('Activar como gestor de credenciales'),
                    ),
                  ],
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  String _unavailableReason(BiometricAvailability availability) =>
      switch (availability) {
        BiometricAvailability.noHardware =>
          'Este dispositivo no tiene $_biometricMethodName configurado.',
        BiometricAvailability.notEnrolled =>
          'Configurá $_biometricMethodName en los ajustes del sistema para '
              'poder activarlo acá.',
        BiometricAvailability.available => '',
        BiometricAvailability.unavailable =>
          'No disponible en este dispositivo.',
      };
}
