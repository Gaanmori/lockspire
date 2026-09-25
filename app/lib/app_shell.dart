// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Lockspire

import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'features/appearance/presentation/screens/appearance_screen.dart';
import 'features/browser_bridge/presentation/screens/browser_integration_screen.dart';
import 'features/home/presentation/home_destination.dart';
import 'features/home/presentation/navigation_layout.dart';
import 'features/home/presentation/screens/settings_screen.dart';
import 'features/home/presentation/widgets/home_shell.dart';
import 'features/sync/presentation/screens/sync_settings_screen.dart';
import 'features/vault/domain/entities/vault.dart';
import 'features/vault/presentation/screens/import_screen.dart';
import 'features/vault/presentation/screens/security_screen.dart';
import 'features/vault/presentation/screens/vault_unlocked_screen.dart';
import 'features/vault/presentation/vault_session_controller.dart';

/// Composición de la navegación principal (Material 3): qué secciones hay
/// y qué pantalla de cada feature va en cada una. Vive a nivel de app,
/// junto a `main.dart`, porque es el único sitio que conoce todas las
/// features; `HomeShell` y `SettingsScreen` no conocen ninguna.
class AppShell extends ConsumerWidget {
  final Vault vault;

  const AppShell({super.key, required this.vault});

  static final _isDesktop = Platform.isWindows || Platform.isLinux;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return HomeShell(
      onLock: () => ref.read(vaultSessionControllerProvider.notifier).lock(),
      destinations: [
        HomeDestination(
          label: 'Bóveda',
          icon: Icons.key_outlined,
          selectedIcon: Icons.key,
          // En el riel, Bloquear ya está al pie: no se repite arriba.
          builder: (_, layout) => VaultUnlockedScreen(
            vault: vault,
            showLockAction: layout == NavigationLayout.bar,
          ),
        ),
        HomeDestination(
          label: 'Sincronización',
          icon: Icons.sync_outlined,
          selectedIcon: Icons.sync,
          builder: (_, _) => const SyncSettingsScreen(),
        ),
        HomeDestination(
          label: 'Seguridad',
          icon: Icons.security_outlined,
          selectedIcon: Icons.security,
          builder: (_, _) => const SecurityScreen(),
        ),
        HomeDestination(
          label: 'Ajustes',
          icon: Icons.settings_outlined,
          selectedIcon: Icons.settings,
          builder: (_, _) => SettingsScreen(
            items: [
              SettingsItem(
                icon: Icons.palette_outlined,
                title: 'Apariencia',
                subtitle: 'Tema claro u oscuro y colores',
                builder: (_) => const AppearanceScreen(),
              ),
              SettingsItem(
                icon: Icons.upload_file_outlined,
                title: 'Importar desde SafeInCloud',
                subtitle: 'Traer tus contraseñas desde un archivo XML',
                builder: (_) => const ImportScreen(),
              ),
              if (_isDesktop)
                SettingsItem(
                  icon: Icons.extension_outlined,
                  title: 'Navegador',
                  subtitle: 'Conectar con la extensión de Chrome/Edge',
                  builder: (_) => const BrowserIntegrationScreen(),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
