// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Lockspire

import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../design/lockspire_spacing.dart';
import '../../domain/auto_lock_timeout.dart';
import '../../domain/ports/biometric_auth_port.dart';
import '../providers/auto_lock_timeout_setting_provider.dart';
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

  // Cuerpo con llaves: `() => _statusFuture = ...` devolvería el Future y
  // setState lo rechaza.
  void _refresh() => setState(() {
    _statusFuture = _loadStatus();
  });

  Future<void> _openAutofillServiceSettings() async {
    try {
      await _settingsChannel.invokeMethod('openAutofillServiceSettings');
    } on PlatformException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.message ?? 'No se pudo abrir la configuración.'),
        ),
      );
    }
  }

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
                  const _AutoLockSection(),
                  const SizedBox(height: LockspireSpacing.lg),
                  const Divider(),
                  const SizedBox(height: LockspireSpacing.md),
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
                      'Activá Lockspire como servicio de autocompletado '
                      'para que aparezca como opción al iniciar sesión en '
                      'otras apps — incluye logins dentro de un navegador '
                      'embebido (ej. WebView).',
                    ),
                    const SizedBox(height: LockspireSpacing.md),
                    OutlinedButton(
                      onPressed: _openAutofillServiceSettings,
                      child: const Text('Activar como autocompletado'),
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

/// Tiempo de bloqueo por inactividad (ADR 0016): 1, 5 o 15 minutos.
class _AutoLockSection extends ConsumerWidget {
  const _AutoLockSection();

  static String _label(AutoLockTimeout timeout) => switch (timeout) {
    AutoLockTimeout.oneMinute => '1 min',
    AutoLockTimeout.fiveMinutes => '5 min',
    AutoLockTimeout.fifteenMinutes => '15 min',
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current =
        ref.watch(autoLockTimeoutSettingProvider).value ??
        AutoLockTimeout.defaultValue;
    final textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Bloqueo automático', style: textTheme.titleMedium),
        const SizedBox(height: LockspireSpacing.sm),
        Text(
          'La bóveda se bloquea sola cuando pasa este tiempo sin que uses '
          'Lockspire. ${Platform.isAndroid ? 'También se bloquea al salir de la app.' : 'También se bloquea al bloquear la sesión o suspender el equipo.'}',
        ),
        const SizedBox(height: LockspireSpacing.md),
        SegmentedButton<AutoLockTimeout>(
          showSelectedIcon: false,
          segments: [
            for (final timeout in AutoLockTimeout.values)
              ButtonSegment(value: timeout, label: Text(_label(timeout))),
          ],
          selected: {current},
          // VaultSessionController escucha el cambio y reprograma el
          // temporizador por su cuenta.
          onSelectionChanged: (selection) => ref
              .read(autoLockTimeoutSettingProvider.notifier)
              .set(selection.first),
        ),
        const SizedBox(height: LockspireSpacing.xs),
        Text(
          current == AutoLockTimeout.fifteenMinutes
              ? 'Más cómodo, pero la bóveda queda abierta más tiempo si te '
                    'alejás del equipo.'
              : ' ',
          style: textTheme.bodySmall,
        ),
      ],
    );
  }
}
