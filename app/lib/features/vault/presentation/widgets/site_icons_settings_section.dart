// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Gabriel Ángel Montoya Rico

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lockspire/l10n/l10n.dart';

import '../providers/site_icons_providers.dart';
import '../site_icons_controller.dart';

/// Íconos de los sitios (ADR 0029, 0030): opcionales porque descargarlos le
/// avisa a cada sitio de una visita desde esta conexión. Se muestra en
/// Apariencia (revisión de ajustes 2026-09-30); lo conecta `app_shell.dart`,
/// así Apariencia no depende de la bóveda.
class SiteIconsSettingsSection extends ConsumerWidget {
  const SiteIconsSettingsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final enabled = ref.watch(siteIconsEnabledProvider).value ?? false;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(
            context.l10n.siteIconsTitle,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          subtitle: Text(context.l10n.siteIconsHint),
          value: enabled,
          onChanged: (value) =>
              ref.read(siteIconsEnabledProvider.notifier).set(value),
        ),
        if (enabled) ...[
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(context.l10n.siteIconsFallback),
            subtitle: Text(context.l10n.siteIconsFallbackHint),
            value: ref.watch(siteIconsFallbackEnabledProvider).value ?? false,
            onChanged: (value) =>
                ref.read(siteIconsFallbackEnabledProvider.notifier).set(value),
          ),
          TextButton.icon(
            onPressed: () async {
              final controller = ref.read(siteIconsControllerProvider);
              await controller.retryMissing();
              await controller.refresh();
            },
            icon: const Icon(Icons.refresh),
            label: Text(context.l10n.siteIconsRetry),
          ),
        ],
      ],
    );
  }
}
