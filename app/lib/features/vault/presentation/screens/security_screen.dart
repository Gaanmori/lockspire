// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Gabriel Ángel Montoya Rico

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lockspire/shared/platform_capabilities.dart';

import '../../../../design/lockspire_spacing.dart';
import '../../domain/auto_lock_timeout.dart';
import '../../domain/master_password_reminder.dart';
import '../../domain/ports/biometric_auth_port.dart';
import '../providers/auto_lock_timeout_setting_provider.dart';
import '../providers/master_password_reminder_setting_provider.dart';
import '../biometric_unlock_controller.dart';
import 'change_master_password_screen.dart';
import 'package:lockspire/l10n/localized_values.dart';
import 'package:lockspire/l10n/l10n.dart';
import '../providers/biometric_status_provider.dart';

/// Nombre del método biométrico de esta plataforma (hallazgo C2).
String _biometricMethodName(BuildContext context, WidgetRef ref) => context.l10n
    .biometricName(ref.watch(platformCapabilitiesProvider).biometricMethod);

/// Contraseña maestra, bloqueo automático, desbloqueo biométrico (ver
/// `BiometricAuthPort`), autocompletado e íconos de sitios. El estado de la
/// biometría sale de `biometricStatusProvider`: también lo cambia el
/// ofrecimiento tras crear la bóveda, y esta pestaña queda construida.
class SecurityScreen extends ConsumerStatefulWidget {
  const SecurityScreen({super.key});

  @override
  ConsumerState<SecurityScreen> createState() => _SecurityScreenState();
}

class _SecurityScreenState extends ConsumerState<SecurityScreen> {
  bool _busy = false;

  void _refresh() => ref.invalidate(biometricStatusProvider);

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
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.securityTitle)),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(LockspireSpacing.lg),
          child: FutureBuilder<(BiometricAvailability, bool)>(
            future: ref.watch(biometricStatusProvider.future),
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
                    _SectionTitle(context.l10n.securityMasterPasswordSection),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.password),
                      title: Text(context.l10n.changePwTitle),
                      subtitle: Text(context.l10n.securityChangePwHint),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: _openChangeMasterPassword,
                    ),
                    const _SectionDivider(),
                    _SectionTitle(context.l10n.securityUnlockSection),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        context.l10n.securityUnlockWith(
                          _biometricMethodName(context, ref),
                        ),
                      ),
                      subtitle: Text(
                        available
                            ? context.l10n.securityUnlockWithHint(
                                _biometricMethodName(context, ref),
                              )
                            : _unavailableReason(availability),
                      ),
                      value: enabled,
                      onChanged: (available && !_busy) ? _toggle : null,
                    ),
                    if (_busy) ...[
                      const SizedBox(height: LockspireSpacing.md),
                      const Center(child: CircularProgressIndicator()),
                    ],
                    // Sin huella siempre se pide la contraseña: el
                    // recordatorio solo tiene sentido con ella activada.
                    if (available && enabled) ...[
                      const SizedBox(height: LockspireSpacing.md),
                      const _MasterPasswordReminderSection(),
                    ],
                    const _SectionDivider(),
                    const _AutoLockSection(),
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

  String _unavailableReason(BiometricAvailability availability) =>
      switch (availability) {
        BiometricAvailability.noHardware =>
          context.l10n.securityBiometricNotSetUp(
            _biometricMethodName(context, ref),
          ),
        BiometricAvailability.notEnrolled =>
          context.l10n.securityBiometricSetUpHint(
            _biometricMethodName(context, ref),
          ),
        BiometricAvailability.available => '',
        BiometricAvailability.unavailable =>
          context.l10n.securityBiometricUnavailable,
      };
}

/// Cada cuánto se exige la contraseña maestra aunque se use biometría (ADR
/// 0017): 7, 14 o 30 días.
class _MasterPasswordReminderSection extends ConsumerWidget {
  const _MasterPasswordReminderSection();

  static String _label(
    AppLocalizations l10n,
    MasterPasswordReminder reminder,
  ) => l10n.commonDays(switch (reminder) {
    MasterPasswordReminder.sevenDays => 7,
    MasterPasswordReminder.fourteenDays => 14,
    MasterPasswordReminder.thirtyDays => 30,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current =
        ref.watch(masterPasswordReminderSettingProvider).value ??
        MasterPasswordReminder.defaultValue;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.l10n.securityReminderTitle,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: LockspireSpacing.sm),
        SegmentedButton<MasterPasswordReminder>(
          showSelectedIcon: false,
          segments: [
            for (final reminder in MasterPasswordReminder.values)
              ButtonSegment(
                value: reminder,
                label: Text(_label(context.l10n, reminder)),
              ),
          ],
          selected: {current},
          onSelectionChanged: (selection) => ref
              .read(masterPasswordReminderSettingProvider.notifier)
              .set(selection.first),
        ),
        const SizedBox(height: LockspireSpacing.xs),
        Text(
          context.l10n.securityReminderHint(_biometricMethodName(context, ref)),
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}

/// Tiempo de bloqueo por inactividad (ADR 0016): 1, 5 o 15 minutos.
class _AutoLockSection extends ConsumerWidget {
  const _AutoLockSection();

  static String _label(AppLocalizations l10n, AutoLockTimeout timeout) =>
      l10n.commonMinutesShort(switch (timeout) {
        AutoLockTimeout.oneMinute => 1,
        AutoLockTimeout.fiveMinutes => 5,
        AutoLockTimeout.fifteenMinutes => 15,
      });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current =
        ref.watch(autoLockTimeoutSettingProvider).value ??
        AutoLockTimeout.defaultValue;
    final textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionTitle(context.l10n.securityAutoLock),
        Text(
          ref.watch(platformCapabilitiesProvider).isAndroid
              ? context.l10n.securityAutoLockHintAndroid
              : context.l10n.securityAutoLockHintDesktop,
        ),
        const SizedBox(height: LockspireSpacing.md),
        SegmentedButton<AutoLockTimeout>(
          showSelectedIcon: false,
          segments: [
            for (final timeout in AutoLockTimeout.values)
              ButtonSegment(
                value: timeout,
                label: Text(_label(context.l10n, timeout)),
              ),
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
              ? context.l10n.securityAutoLock15Warning
              : ' ',
          style: textTheme.bodySmall,
        ),
      ],
    );
  }
}

/// Título de un grupo de Seguridad: todos con el mismo estilo (revisión de
/// ajustes 2026-09-30).
class _SectionTitle extends StatelessWidget {
  final String text;

  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: LockspireSpacing.sm),
    child: Text(text, style: Theme.of(context).textTheme.titleMedium),
  );
}

class _SectionDivider extends StatelessWidget {
  const _SectionDivider();

  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.symmetric(vertical: LockspireSpacing.md),
    child: Divider(),
  );
}
