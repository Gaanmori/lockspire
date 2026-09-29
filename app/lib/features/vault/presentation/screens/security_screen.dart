// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Gabriel Ángel Montoya Rico

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lockspire/shared/platform_capabilities.dart';

import '../../../../design/lockspire_spacing.dart';
import '../../domain/auto_lock_timeout.dart';
import '../../domain/master_password_reminder.dart';
import '../../domain/ports/biometric_auth_port.dart';
import '../providers/auto_lock_timeout_setting_provider.dart';
import '../providers/biometric_auth_port_provider.dart';
import '../providers/master_password_reminder_setting_provider.dart';
import '../biometric_unlock_controller.dart';
import '../providers/site_icons_providers.dart';
import '../site_icons_controller.dart';
import 'change_master_password_screen.dart';

const _settingsChannel = MethodChannel('com.lockspire.lockspire/settings');

/// Nombre del método biométrico de esta plataforma (hallazgo C2).
String _biometricMethodName(WidgetRef ref) =>
    ref.watch(platformCapabilitiesProvider).biometricMethodName;

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
    final controller = ref.read(biometricUnlockControllerProvider);
    if (value) {
      await controller.enable();
    } else {
      await controller.disable();
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

              return SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.password),
                      title: const Text('Cambiar contraseña maestra'),
                      subtitle: const Text(
                        'Hágalo si cree que alguien pudo conocerla.',
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: _openChangeMasterPassword,
                    ),
                    const Divider(),
                    const SizedBox(height: LockspireSpacing.md),
                    const _AutoLockSection(),
                    const SizedBox(height: LockspireSpacing.lg),
                    const Divider(),
                    const SizedBox(height: LockspireSpacing.md),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        'Desbloquear con ${_biometricMethodName(ref)}',
                      ),
                      subtitle: Text(
                        available
                            ? 'Use ${_biometricMethodName(ref)} en vez de escribir la '
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
                    if (available) ...[
                      const SizedBox(height: LockspireSpacing.md),
                      const _MasterPasswordReminderSection(),
                    ],
                    const SizedBox(height: LockspireSpacing.lg),
                    const Divider(),
                    const SizedBox(height: LockspireSpacing.md),
                    const _SiteIconsSection(),
                    if (ref.watch(platformCapabilitiesProvider).isAndroid) ...[
                      const SizedBox(height: LockspireSpacing.lg),
                      const Divider(),
                      const SizedBox(height: LockspireSpacing.md),
                      Text(
                        'Autocompletado',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: LockspireSpacing.sm),
                      const Text(
                        'Active Lockspire como servicio de autocompletado '
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
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Future<void> _openChangeMasterPassword() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const ChangeMasterPasswordScreen(),
      ),
    );
    // Cambiar la contraseña puede desactivar la biometría (ADR 0018).
    if (mounted) _refresh();
  }

  String _unavailableReason(
    BiometricAvailability availability,
  ) => switch (availability) {
    BiometricAvailability.noHardware =>
      'Este dispositivo no tiene ${_biometricMethodName(ref)} configurado.',
    BiometricAvailability.notEnrolled =>
      'Configure ${_biometricMethodName(ref)} en los ajustes del sistema para '
          'poder activarlo acá.',
    BiometricAvailability.available => '',
    BiometricAvailability.unavailable => 'No disponible en este dispositivo.',
  };
}

/// Cada cuánto se exige la contraseña maestra aunque se use biometría (ADR
/// 0017): 7, 14 o 30 días.
class _MasterPasswordReminderSection extends ConsumerWidget {
  const _MasterPasswordReminderSection();

  static String _label(MasterPasswordReminder reminder) => switch (reminder) {
    MasterPasswordReminder.sevenDays => '7 días',
    MasterPasswordReminder.fourteenDays => '14 días',
    MasterPasswordReminder.thirtyDays => '30 días',
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current =
        ref.watch(masterPasswordReminderSettingProvider).value ??
        MasterPasswordReminder.defaultValue;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Pedir la contraseña maestra cada',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: LockspireSpacing.sm),
        SegmentedButton<MasterPasswordReminder>(
          showSelectedIcon: false,
          segments: [
            for (final reminder in MasterPasswordReminder.values)
              ButtonSegment(value: reminder, label: Text(_label(reminder))),
          ],
          selected: {current},
          onSelectionChanged: (selection) => ref
              .read(masterPasswordReminderSettingProvider.notifier)
              .set(selection.first),
        ),
        const SizedBox(height: LockspireSpacing.xs),
        Text(
          'Aunque use ${_biometricMethodName(ref)}, pasado este tiempo Lockspire '
          'le pide la contraseña una vez, para que no se le olvide. Si la '
          'olvida, la bóveda no se puede recuperar.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
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
          'La bóveda se bloquea sola cuando pasa este tiempo sin que use '
          'Lockspire. ${ref.watch(platformCapabilitiesProvider).isAndroid ? 'También se bloquea al salir de la app.' : 'También se bloquea al bloquear la sesión o suspender el equipo.'}',
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
              ? 'Más cómodo, pero la bóveda queda abierta más tiempo si se '
                    'aleja del equipo.'
              : ' ',
          style: textTheme.bodySmall,
        ),
      ],
    );
  }
}

/// Íconos de los sitios (ADR 0029): opcional porque descargarlos le avisa a
/// cada sitio de una visita desde esta conexión.
class _SiteIconsSection extends ConsumerWidget {
  const _SiteIconsSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final enabled = ref.watch(siteIconsEnabledProvider).value ?? false;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Íconos de los sitios'),
          subtitle: const Text(
            'Descarga el ícono de cada sitio guardado directamente del '
            'sitio, sin servicios de terceros, y lo guarda cifrado en su '
            'bóveda. Cada sitio ve una visita desde su conexión. Sin '
            'activarlo, se muestra la inicial.',
          ),
          value: enabled,
          onChanged: (value) =>
              ref.read(siteIconsEnabledProvider.notifier).set(value),
        ),
        if (enabled)
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Completar los que falten con DuckDuckGo'),
            subtitle: const Text(
              'Para los sitios que no ofrecen ícono, se lo pide a '
              'DuckDuckGo. DuckDuckGo recibe solo esos dominios, nunca sus '
              'usuarios ni contraseñas.',
            ),
            value: ref.watch(siteIconsFallbackEnabledProvider).value ?? false,
            onChanged: (value) =>
                ref.read(siteIconsFallbackEnabledProvider.notifier).set(value),
          ),
        if (enabled)
          TextButton.icon(
            onPressed: () async {
              final controller = ref.read(siteIconsControllerProvider);
              await controller.retryMissing();
              await controller.refresh();
            },
            icon: const Icon(Icons.refresh),
            label: const Text('Volver a buscar los que faltan'),
          ),
      ],
    );
  }
}
