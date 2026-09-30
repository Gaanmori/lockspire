// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Gabriel Ángel Montoya Rico

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lockspire/l10n/l10n.dart';

import '../../../../design/lockspire_spacing.dart';
import '../providers/system_autofill_settings_port_provider.dart';

/// Activar Lockspire como servicio de autocompletado de Android (ADR 0011).
/// Está en Ajustes → Integraciones, junto a Navegador en escritorio
/// (revisión de ajustes 2026-09-30); antes vivía en Seguridad.
class AutofillSettingsScreen extends ConsumerWidget {
  const AutofillSettingsScreen({super.key});

  Future<void> _openSystemSettings(BuildContext context, WidgetRef ref) async {
    final opened = await ref.read(systemAutofillSettingsPortProvider).open();
    if (opened || !context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(context.l10n.autofillSettingsOpenFailed)),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.autofillSettingsTitle)),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(LockspireSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(context.l10n.autofillSettingsHint),
              const SizedBox(height: LockspireSpacing.lg),
              FilledButton(
                onPressed: () => _openSystemSettings(context, ref),
                child: Text(context.l10n.autofillSettingsButton),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
