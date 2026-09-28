// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Lockspire

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lockspire/shared/platform_capabilities.dart';

import '../../../../design/lockspire_spacing.dart';
import '../../domain/entities/vault.dart';
import '../../domain/entities/entry_fields.dart';
import '../../domain/entities/vault_entry.dart';
import '../../domain/ports/biometric_auth_port.dart';
import '../providers/biometric_auth_port_provider.dart';
import '../biometric_unlock_controller.dart';
import '../vault_entries_controller.dart';
import '../vault_session_controller.dart';
import 'entry_form_screen.dart';
import '../widgets/entry_type_label.dart';
import '../widgets/entry_tile.dart';

/// Lista de entradas de la bóveda desbloqueada, con búsqueda y acceso a
/// crear/editar (ver `EntryFormScreen`).
class VaultUnlockedScreen extends ConsumerStatefulWidget {
  final Vault vault;

  /// Mostrar Bloquear en la barra superior. Quien compone la pantalla lo
  /// desactiva cuando la navegación ya lo ofrece (riel en escritorio).
  final bool showLockAction;

  const VaultUnlockedScreen({
    super.key,
    required this.vault,
    this.showLockAction = true,
  });

  @override
  ConsumerState<VaultUnlockedScreen> createState() =>
      _VaultUnlockedScreenState();
}

class _VaultUnlockedScreenState extends ConsumerState<VaultUnlockedScreen> {
  final _searchController = TextEditingController();
  String _query = '';

  /// Ids seleccionados; `null` = no se está seleccionando.
  Set<String>? _selected;

  bool get _selecting => _selected != null;

  void _toggle(VaultEntry entry) => setState(() {
    final selected = _selected ??= {};
    if (!selected.remove(entry.id)) selected.add(entry.id);
  });

  Future<void> _deleteSelected() async {
    final ids = _selected ?? const <String>{};
    if (ids.isEmpty) return;
    final n = ids.length;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(n == 1 ? '¿Eliminar 1 entrada?' : '¿Eliminar $n entradas?'),
        content: const Text(
          'Se eliminan de la bóveda en este dispositivo y en los demás al '
          'sincronizar.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(dialogContext).colorScheme.error,
              foregroundColor: Theme.of(dialogContext).colorScheme.onError,
            ),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await ref.read(vaultEntriesControllerProvider).deleteEntries(ids);
    if (!mounted) return;
    setState(() => _selected = null);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          n == 1 ? 'Se eliminó 1 entrada' : 'Se eliminaron $n entradas',
        ),
      ),
    );
  }

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

    final methodName = ref
        .read(platformCapabilitiesProvider)
        .biometricMethodName;
    final activar = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('¿Activar desbloqueo con $methodName?'),
        content: Text(
          'En vez de escribir la contraseña maestra cada vez, vas a poder '
          'desbloquear la bóveda con $methodName. Puede cambiarlo después '
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
      await ref.read(biometricUnlockControllerProvider).enable();
    } else {
      await port.markOnboardingDismissed();
    }
  }

  List<VaultEntry> get _filteredEntries {
    final query = _query.trim().toLowerCase();
    final visible = widget.vault.entries.where((e) => !e.deleted);
    bool contains(String? value) =>
        value?.toLowerCase().contains(query) ?? false;
    final matching = query.isEmpty
        ? visible
        : visible.where(
            (e) =>
                contains(e.title) ||
                contains(e.fields[EntryFields.username]) ||
                contains(e.fields[EntryFields.cardHolder]) ||
                contains(e.fields[EntryFields.docName]) ||
                e.urls.any(contains),
          );
    return matching.toList()
      ..sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
  }

  /// Elige qué crear: contraseña, tarjeta o documento (ADR 0025).
  Future<void> _addEntry() async {
    final type = await showModalBottomSheet<VaultEntryType>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final (type, label) in const [
              (VaultEntryType.password, 'Contraseña'),
              (VaultEntryType.card, 'Tarjeta'),
              (VaultEntryType.document, 'Documento'),
            ])
              ListTile(
                leading: Icon(type.icon),
                title: Text(label),
                onTap: () => Navigator.of(sheetContext).pop(type),
              ),
          ],
        ),
      ),
    );
    if (type == null || !mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => EntryFormScreen(type: type)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final entries = _filteredEntries;

    final selected = _selected ?? const <String>{};
    final allSelected =
        entries.isNotEmpty && entries.every((e) => selected.contains(e.id));

    return Scaffold(
      appBar: _selecting
          ? AppBar(
              leading: IconButton(
                icon: const Icon(Icons.close),
                tooltip: 'Cancelar selección',
                onPressed: () => setState(() => _selected = null),
              ),
              title: Text('${selected.length} seleccionadas'),
              actions: [
                IconButton(
                  icon: Icon(allSelected ? Icons.deselect : Icons.select_all),
                  tooltip: allSelected
                      ? 'Quitar selección'
                      : 'Seleccionar todo',
                  onPressed: () => setState(
                    () => _selected = allSelected
                        ? <String>{}
                        : {for (final e in entries) e.id},
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline),
                  tooltip: 'Eliminar seleccionadas',
                  onPressed: selected.isEmpty ? null : _deleteSelected,
                ),
              ],
            )
          : AppBar(
              title: const Text('Lockspire'),
              // Sincronización, Seguridad y Ajustes están en la navegación
              // principal (`HomeShell`); aquí solo queda lo propio de la bóveda.
              actions: [
                if (entries.isNotEmpty)
                  IconButton(
                    icon: const Icon(Icons.checklist),
                    tooltip: 'Seleccionar',
                    onPressed: () => setState(() => _selected = <String>{}),
                  ),
                if (widget.showLockAction)
                  IconButton(
                    icon: const Icon(Icons.lock),
                    tooltip: 'Bloquear',
                    onPressed: () => ref
                        .read(vaultSessionControllerProvider.notifier)
                        .lock(),
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
                hintText: 'Buscar por título, usuario o sitio',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (value) => setState(() => _query = value),
            ),
          ),
          Expanded(
            child: entries.isEmpty
                ? VaultEmptyState(hasQuery: _query.trim().isNotEmpty)
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
                      return EntryTile(
                        entry: entry,
                        selected: _selecting
                            ? selected.contains(entry.id)
                            : null,
                        onLongPress: () => _toggle(entry),
                        onTap: _selecting
                            ? () => _toggle(entry)
                            : () => Navigator.of(context).push(
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
      floatingActionButton: _selecting
          ? null
          : FloatingActionButton(
              tooltip: 'Agregar',
              onPressed: _addEntry,
              child: const Icon(Icons.add),
            ),
    );
  }
}
