// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Lockspire

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lockspire/design/lockspire_colors.dart';
import 'package:lockspire/design/lockspire_spacing.dart';
import 'package:lockspire/features/vault/domain/entities/vault_entry.dart';

import '../../application/sync_vault_use_case.dart';
import '../../domain/vault_merge.dart';
import '../sync_controller.dart';

/// Resuelve, de a un conflicto por vez, las entradas que cambiaron
/// distinto en ambos lados desde la última sincronización (ver ADR 0006 —
/// esta pasada usa un picker manual, "una gana", no "mantener ambas").
///
/// Sin escribir ni subir nada hasta que el usuario termina de elegir todos
/// los conflictos — ver `SyncVaultUseCase.completeMerge`.
class ConflictResolutionScreen extends ConsumerStatefulWidget {
  final SyncNeedsResolution pending;

  const ConflictResolutionScreen({super.key, required this.pending});

  @override
  ConsumerState<ConflictResolutionScreen> createState() =>
      _ConflictResolutionScreenState();
}

class _ConflictResolutionScreenState
    extends ConsumerState<ConflictResolutionScreen> {
  int _index = 0;
  final Map<String, VaultEntry> _resolutions = {};
  bool _submitting = false;
  String? _errorMessage;

  List<EntryConflict> get _conflicts => widget.pending.conflicts;

  Future<void> _choose(EntryConflict conflict, VaultEntry chosen) async {
    _resolutions[conflict.local.id] = chosen;

    if (_index + 1 < _conflicts.length) {
      setState(() => _index++);
      return;
    }

    setState(() {
      _submitting = true;
      _errorMessage = null;
    });

    try {
      await ref
          .read(syncControllerProvider.notifier)
          .completeMerge(widget.pending, _resolutions);
      if (mounted) Navigator.of(context).pop();
    } on SyncStaleMergeException catch (e) {
      // A diferencia de otros errores, este `pending` ya no sirve para
      // reintentar — los hashes contra los que se comparó quedaron
      // obsoletos, así que cualquier intento con la misma resolución va a
      // fallar exactamente igual. Hay que volver a la pantalla de sync
      // para que el usuario dispare un análisis nuevo desde cero (ver
      // docs/STATE.md — Fase 7), no reintentar acá.
      if (!mounted) return;
      setState(() => _submitting = false);
      await showDialog<void>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Los datos cambiaron'),
          content: Text(e.toString()),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Entendido'),
            ),
          ],
        ),
      );
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        setState(() {
          _submitting = false;
          _errorMessage = 'No se pudo terminar la sincronización: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final conflict = _conflicts[_index];

    return Scaffold(
      appBar: AppBar(
        title: Text('Resolver conflicto ${_index + 1} de ${_conflicts.length}'),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Padding(
            padding: const EdgeInsets.all(LockspireSpacing.lg),
            child: _submitting
                ? const Center(child: CircularProgressIndicator())
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Esta entrada cambió distinto en cada dispositivo. '
                        'Elegí qué versión conservar — la otra se descarta.',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: LockspireSpacing.lg),
                      if (_errorMessage != null)
                        Padding(
                          padding: const EdgeInsets.only(
                            bottom: LockspireSpacing.md,
                          ),
                          child: Text(
                            _errorMessage!,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      _EntryVersionCard(
                        label: 'Este dispositivo',
                        entry: conflict.local,
                        onChoose: () => _choose(conflict, conflict.local),
                      ),
                      const SizedBox(height: LockspireSpacing.md),
                      _EntryVersionCard(
                        label: 'Otro dispositivo',
                        entry: conflict.remote,
                        onChoose: () => _choose(conflict, conflict.remote),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

class _EntryVersionCard extends StatelessWidget {
  final String label;
  final VaultEntry entry;
  final VoidCallback onChoose;

  const _EntryVersionCard({
    required this.label,
    required this.entry,
    required this.onChoose,
  });

  @override
  Widget build(BuildContext context) {
    final username = entry.fields['username'];
    final url = entry.fields['url'];
    final hasPassword = (entry.fields['password'] ?? '').isNotEmpty;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(LockspireSpacing.md),
      decoration: BoxDecoration(
        color: LockspireColors.bgSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: LockspireColors.bgInput),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.labelMedium),
          const SizedBox(height: LockspireSpacing.xs),
          Text(entry.title, style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: LockspireSpacing.sm),
          if (username != null && username.isNotEmpty)
            Text('Usuario: $username'),
          if (hasPassword) const Text('Contraseña: ••••••••'),
          if (url != null && url.isNotEmpty) Text('URL: $url'),
          const SizedBox(height: LockspireSpacing.md),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: onChoose,
              child: const Text('Usar esta versión'),
            ),
          ),
        ],
      ),
    );
  }
}
