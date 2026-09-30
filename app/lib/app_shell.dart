// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Gabriel Ángel Montoya Rico

import 'features/profiles/presentation/screens/profiles_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'shared/platform_capabilities.dart';
import 'features/about/presentation/screens/about_screen.dart';
import 'features/appearance/presentation/screens/appearance_screen.dart';
import 'features/autofill/presentation/screens/autofill_settings_screen.dart';
import 'features/browser_bridge/presentation/screens/browser_integration_screen.dart';
import 'features/home/presentation/home_destination.dart';
import 'features/home/presentation/navigation_layout.dart';
import 'features/home/presentation/screens/settings_screen.dart';
import 'features/home/presentation/widgets/home_shell.dart';
import 'features/sync/presentation/screens/sync_settings_screen.dart';
import 'features/sync/presentation/widgets/password_changed_elsewhere_banner.dart';
import 'features/sync/presentation/widgets/sync_home_banner.dart';
import 'features/vault/domain/entities/vault.dart';
import 'features/vault/presentation/screens/export_screen.dart';
import 'features/vault/presentation/screens/import_screen.dart';
import 'features/vault/presentation/screens/security_screen.dart';
import 'features/vault/presentation/screens/vault_unlocked_screen.dart';
import 'features/vault/presentation/widgets/site_icons_settings_section.dart';
import 'features/vault/presentation/vault_session_controller.dart';
import 'package:lockspire/l10n/l10n.dart';

/// Composición de la navegación principal (Material 3): qué secciones hay
/// y qué pantalla de cada feature va en cada una. Vive a nivel de app,
/// junto a `main.dart`, porque es el único sitio que conoce todas las
/// features; `HomeShell` y `SettingsScreen` no conocen ninguna.
class AppShell extends ConsumerWidget {
  final Vault vault;

  const AppShell({super.key, required this.vault});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return HomeShell(
      onLock: () => ref.read(vaultSessionControllerProvider.notifier).lock(),
      banner: const Column(
        mainAxisSize: MainAxisSize.min,
        children: [PasswordChangedElsewhereBanner(), SyncHomeBanner()],
      ),
      destinations: [
        HomeDestination(
          label: context.l10n.navVault,
          icon: Icons.key_outlined,
          selectedIcon: Icons.key,
          // En el riel, Bloquear ya está al pie: no se repite arriba.
          builder: (_, layout) => VaultUnlockedScreen(
            vault: vault,
            showLockAction: layout == NavigationLayout.bar,
          ),
        ),
        HomeDestination(
          label: context.l10n.syncTitle,
          icon: Icons.sync_outlined,
          selectedIcon: Icons.sync,
          builder: (_, _) => const SyncSettingsScreen(),
        ),
        HomeDestination(
          label: context.l10n.securityTitle,
          icon: Icons.security_outlined,
          selectedIcon: Icons.security,
          builder: (_, _) => const SecurityScreen(),
        ),
        HomeDestination(
          label: context.l10n.settingsTitle,
          icon: Icons.settings_outlined,
          selectedIcon: Icons.settings,
          builder: (_, _) {
            final platform = ref.watch(platformCapabilitiesProvider);
            return SettingsScreen(
              sections: [
                SettingsSection(
                  title: context.l10n.settingsGeneral,
                  items: [
                    SettingsItem(
                      icon: Icons.palette_outlined,
                      title: context.l10n.appearanceTitle,
                      subtitle: context.l10n.settingsAppearanceHint,
                      builder: (_) => const AppearanceScreen(
                        extraSections: [SiteIconsSettingsSection()],
                      ),
                    ),
                    // Varias bóvedas en el dispositivo (ADR 0039). En
                    // Android se activan ahí mismo.
                    SettingsItem(
                      icon: Icons.people_outline,
                      title: context.l10n.profilesTitle,
                      subtitle: context.l10n.profilesSubtitle,
                      builder: (_) => const ProfilesScreen(),
                    ),
                  ],
                ),
                // Cómo se usa Lockspire fuera de la app: autocompletado en
                // Android, la extensión en escritorio.
                SettingsSection(
                  title: context.l10n.settingsIntegrations,
                  items: [
                    if (platform.isAndroid)
                      SettingsItem(
                        icon: Icons.password_outlined,
                        title: context.l10n.autofillSettingsTitle,
                        subtitle: context.l10n.settingsAutofillHint,
                        builder: (_) => const AutofillSettingsScreen(),
                      ),
                    if (platform.isDesktop)
                      SettingsItem(
                        icon: Icons.extension_outlined,
                        title: context.l10n.browserTitle,
                        subtitle: context.l10n.settingsBrowserHint,
                        builder: (_) => const BrowserIntegrationScreen(),
                      ),
                  ],
                ),
                SettingsSection(
                  title: context.l10n.settingsData,
                  items: [
                    SettingsItem(
                      icon: Icons.upload_file_outlined,
                      title: context.l10n.importTitle,
                      subtitle: context.l10n.settingsImportHint,
                      builder: (_) => const ImportScreen(),
                    ),
                    SettingsItem(
                      icon: Icons.download_outlined,
                      title: context.l10n.exportTitle,
                      subtitle: context.l10n.settingsExportHint,
                      builder: (_) => const ExportScreen(),
                    ),
                  ],
                ),
                SettingsSection(
                  items: [
                    SettingsItem(
                      icon: Icons.info_outline,
                      title: context.l10n.aboutTitle,
                      subtitle: context.l10n.settingsAboutHint,
                      builder: (_) => const AboutScreen(),
                    ),
                  ],
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}
