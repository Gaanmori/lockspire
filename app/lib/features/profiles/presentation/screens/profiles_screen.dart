// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Gabriel Ángel Montoya Rico

import '../../../../design/readable_width.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lockspire/l10n/l10n.dart';
import 'package:lockspire/l10n/localized_error.dart';
import 'package:lockspire/shared/platform_capabilities.dart';
import 'package:lockspire/shared/active_profile_provider.dart';

import '../../../../design/lockspire_spacing.dart';
import '../profiles_controller.dart';
import '../widgets/profile_widgets.dart';

/// Ajustes → Perfiles (ADR 0039): varias bóvedas en el mismo dispositivo.
class ProfilesScreen extends ConsumerWidget {
  const ProfilesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final registry = ref.watch(profilesControllerProvider).value;
    final enabled = ref.watch(profilesEnabledProvider);
    final activeId = ref.watch(activeProfileIdProvider);
    final controller = ref.read(profilesControllerProvider.notifier);
    final isAndroid = ref.watch(platformCapabilitiesProvider).isAndroid;
    final active = registry?.byId(activeId);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.profilesTitle)),
      body: ReadableWidth(
        child: ListView(
          padding: const EdgeInsets.symmetric(vertical: LockspireSpacing.md),
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: LockspireSpacing.md,
              ),
              child: Text(l10n.profilesIntro),
            ),
            const SizedBox(height: LockspireSpacing.md),
            if (isAndroid)
              SwitchListTile(
                title: Text(l10n.profilesEnable),
                subtitle: Text(l10n.profilesEnableHint),
                value: enabled,
                onChanged: (value) =>
                    _run(context, () => controller.setEnabled(value)),
              ),
            if (enabled && registry != null) ...[
              for (final profile in registry.profiles)
                ListTile(
                  leading: const Icon(Icons.person_outline),
                  title: Text(profileDisplayName(context, profile)),
                  subtitle: Text(
                    [
                      // Con nombre propio, se aclara cuál es el principal.
                      if (profile.isMain && profile.name.isNotEmpty)
                        l10n.profilesMainName,
                      if (profile.id == activeId) l10n.profilesInUse,
                    ].join(' · '),
                  ),
                  trailing: profile.id == activeId
                      ? const Icon(Icons.check)
                      : TextButton(
                          onPressed: () => controller.open(profile.id),
                          child: Text(l10n.profilesSwitch),
                        ),
                ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.person_add_alt_outlined),
                title: Text(l10n.profilesAdd),
                onTap: () => addProfile(context, ref),
              ),
              if (active != null)
                ListTile(
                  leading: const Icon(Icons.edit_outlined),
                  title: Text(l10n.profilesRename),
                  onTap: () => showDialog<void>(
                    context: context,
                    builder: (_) => ProfileNameDialog(
                      title: l10n.profilesRenameTitle,
                      confirm: l10n.commonSave,
                      initialName: profileDisplayName(context, active),
                      onSubmit: (name) => controller.renameActive(
                        name,
                        mainDisplayName: l10n.profilesMainName,
                      ),
                    ),
                  ),
                ),
              if (active != null && !active.isMain)
                ListTile(
                  leading: Icon(
                    Icons.delete_outline,
                    color: Theme.of(context).colorScheme.error,
                  ),
                  title: Text(
                    l10n.profilesDelete,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                  onTap: () => _confirmDelete(context, ref, active.name),
                ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    String name,
  ) async {
    final l10n = context.l10n;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.profilesDeleteTitle(name)),
        content: Text(l10n.profilesDeleteBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.commonCancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(dialogContext).colorScheme.error,
              foregroundColor: Theme.of(dialogContext).colorScheme.onError,
            ),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.commonDelete),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    await _run(
      context,
      ref.read(profilesControllerProvider.notifier).deleteActive,
    );
  }

  /// Lo que rechace el dominio (desactivar con varios perfiles) o falle al
  /// guardar se avisa abajo, sin cambiar nada.
  Future<void> _run(
    BuildContext context,
    Future<void> Function() action,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final l10n = context.l10n;
    try {
      await action();
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(localizeError(l10n, e))));
    }
  }
}
