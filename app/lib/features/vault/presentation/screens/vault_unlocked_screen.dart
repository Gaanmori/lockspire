// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Lockspire

import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lockspire/features/sync/presentation/screens/sync_settings_screen.dart';

import '../../../../design/lockspire_colors.dart';
import '../../../../design/lockspire_spacing.dart';
import '../../domain/entities/vault.dart';
import '../../domain/entities/vault_entry.dart';
import '../../domain/ports/biometric_auth_port.dart';
import '../providers/biometric_auth_port_provider.dart';
import '../vault_session_controller.dart';
import 'entry_form_screen.dart';
import 'import_screen.dart';
import 'security_screen.dart';

/// Lista de entradas de la bóveda desbloqueada, con búsqueda y acceso a
/// crear/editar (ver `EntryFormScreen`).
class VaultUnlockedScreen extends ConsumerStatefulWidget {
  final Vault vault;

  const VaultUnlockedScreen({super.key, required this.vault});

  @override
  ConsumerState<VaultUnlockedScreen> createState() =>
      _VaultUnlockedScreenState();
}

class _VaultUnlockedScreenState extends ConsumerState<VaultUnlockedScreen> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _maybeShowBiometricOptIn(),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// Aviso único de opt-in (ver docs/STATE.md/ADR 0010): se ofrece una
  /// sola vez, la primera vez que hay biometría disponible y todavía no
  /// se decidió nada — nunca se vuelve a mostrar después de que el
  /// usuario responde algo, sin importar si dijo que sí o que no. No
  /// distingue si se llegó acá por desbloqueo con contraseña o con
  /// biometría — chequear `hasStoredKey()`/`wasOnboardingDismissed()`
  /// ya cubre ambos casos sin duplicar la lógica en cada pantalla de
  /// desbloqueo.
  Future<void> _maybeShowBiometricOptIn() async {
    final port = ref.read(biometricAuthPortProvider);
    if (await port.checkAvailability() != BiometricAvailability.available) {
      return;
    }
    if (await port.hasStoredKey()) return;
    if (await port.wasOnboardingDismissed()) return;
    if (!mounted) return;

    final methodName = Platform.isWindows ? 'Windows Hello' : 'la huella';
    final activar = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('¿Activar desbloqueo con $methodName?'),
        content: Text(
          'En vez de escribir la contraseña maestra cada vez, vas a poder '
          'desbloquear la bóveda con $methodName. Podés cambiarlo después '
          'desde "Seguridad".',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Ahora no'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Activar'),
          ),
        ],
      ),
    );
    if (!mounted) return;
    if (activar == true) {
      await ref
          .read(vaultSessionControllerProvider.notifier)
          .enableBiometricUnlock();
    } else {
      await port.markOnboardingDismissed();
    }
  }

  List<VaultEntry> get _filteredEntries {
    final query = _query.trim().toLowerCase();
    final visible = widget.vault.entries.where((e) => !e.deleted);
    final matching = query.isEmpty
        ? visible
        : visible.where(
            (e) =>
                e.title.toLowerCase().contains(query) ||
                (e.fields['username']?.toLowerCase().contains(query) ?? false),
          );
    return matching.toList()
      ..sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
  }

  @override
  Widget build(BuildContext context) {
    final entries = _filteredEntries;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Lockspire'),
        actions: [
          IconButton(
            icon: const Icon(Icons.upload_file_outlined),
            tooltip: 'Importar desde SafeInCloud',
            onPressed: () => Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => const ImportScreen())),
          ),
          IconButton(
            icon: const Icon(Icons.sync),
            tooltip: 'Sincronización',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const SyncSettingsScreen()),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.security_outlined),
            tooltip: 'Seguridad',
            onPressed: () => Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => const SecurityScreen())),
          ),
          IconButton(
            icon: const Icon(Icons.lock),
            tooltip: 'Bloquear',
            onPressed: () =>
                ref.read(vaultSessionControllerProvider.notifier).lock(),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              LockspireSpacing.lg,
              LockspireSpacing.md,
              LockspireSpacing.lg,
              LockspireSpacing.sm,
            ),
            child: TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                hintText: 'Buscar por título o usuario',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (value) => setState(() => _query = value),
            ),
          ),
          Expanded(
            child: entries.isEmpty
                ? _EmptyState(hasQuery: _query.trim().isNotEmpty)
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(
                      LockspireSpacing.lg,
                      LockspireSpacing.sm,
                      LockspireSpacing.lg,
                      LockspireSpacing.xxl,
                    ),
                    itemCount: entries.length,
                    separatorBuilder: (_, _) =>
                        const SizedBox(height: LockspireSpacing.sm),
                    itemBuilder: (context, index) {
                      final entry = entries[index];
                      return _EntryTile(
                        entry: entry,
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => EntryFormScreen(entry: entry),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        tooltip: 'Agregar contraseña',
        onPressed: () => Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (_) => const EntryFormScreen())),
        child: const Icon(Icons.add),
      ),
    );
  }
}

/// Fila de lista — icono/inicial + título + subtítulo + chevron, ver
/// docs/design/README.md.
class _EntryTile extends StatelessWidget {
  final VaultEntry entry;
  final VoidCallback onTap;

  const _EntryTile({required this.entry, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final username = entry.fields['username'];
    final subtitle = (username != null && username.isNotEmpty)
        ? username
        : null;
    final initial = entry.title.isNotEmpty ? entry.title[0].toUpperCase() : '?';

    return Material(
      color: LockspireColors.bgSurface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: LockspireSpacing.md,
            vertical: LockspireSpacing.smMd,
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  color: LockspireColors.bgSurfaceSubtle,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  initial,
                  style: const TextStyle(
                    color: LockspireColors.accentDefault,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: LockspireSpacing.smMd),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.title,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    if (subtitle != null)
                      Text(
                        subtitle,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right,
                color: LockspireColors.textPlaceholder,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final bool hasQuery;

  const _EmptyState({required this.hasQuery});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(LockspireSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              hasQuery ? Icons.search_off : Icons.password_outlined,
              size: 48,
              color: LockspireColors.textPlaceholder,
            ),
            const SizedBox(height: LockspireSpacing.md),
            Text(
              hasQuery
                  ? 'No se encontraron resultados'
                  : 'Todavía no guardaste ninguna contraseña',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            if (!hasQuery) ...[
              const SizedBox(height: LockspireSpacing.xs),
              Text(
                'Tocá el botón "+" para agregar la primera',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
