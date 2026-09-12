// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Lockspire

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../design/lockspire_colors.dart';
import '../../../../design/lockspire_spacing.dart';
import '../../../vault/domain/entities/vault.dart';
import '../../../vault/domain/entities/vault_entry.dart';
import '../../../vault/presentation/vault_session_controller.dart';
import '../../domain/match_entries_for_package.dart';

const _channel = MethodChannel('com.lockspire.lockspire/autofill');

/// Pantalla mostrada dentro de `AutofillActivity` (ADR 0011) una vez que
/// la bóveda ya está desbloqueada — la parte nativa (Kotlin) nunca ve
/// nada de esto, solo reenvía el resultado final.
class AutofillScreen extends ConsumerStatefulWidget {
  final Vault vault;

  const AutofillScreen({super.key, required this.vault});

  @override
  ConsumerState<AutofillScreen> createState() => _AutofillScreenState();
}

class _AutofillScreenState extends ConsumerState<AutofillScreen> {
  Future<Map<String, dynamic>>? _requestFuture;

  @override
  void initState() {
    super.initState();
    _requestFuture = _fetchRequest();
  }

  Future<Map<String, dynamic>> _fetchRequest() async {
    final result = await _channel.invokeMethod<Map<Object?, Object?>>(
      'getRequest',
    );
    return (result ?? const {}).map((key, value) => MapEntry('$key', value));
  }

  Future<void> _cancel() => _channel.invokeMethod('cancel');

  Future<void> _submitGet(VaultEntry entry) =>
      _channel.invokeMethod('submitGet', {
        'username': entry.fields['username'] ?? '',
        'password': entry.fields['password'] ?? '',
      });

  Future<void> _submitCreate({
    required String packageName,
    required String username,
    required String password,
  }) async {
    await ref
        .read(vaultSessionControllerProvider.notifier)
        .addEntry(
          title: packageName,
          fields: {'username': username, 'password': password},
        );
    await _channel.invokeMethod('submitCreate');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Lockspire'),
        leading: IconButton(icon: const Icon(Icons.close), onPressed: _cancel),
      ),
      body: SafeArea(
        child: FutureBuilder<Map<String, dynamic>>(
          future: _requestFuture,
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final request = snapshot.data!;
            return switch (request['mode']) {
              'get' => _GetCredentialView(
                vault: widget.vault,
                packageName: request['packageName'] as String? ?? '',
                onPick: _submitGet,
              ),
              'create' => _CreateCredentialView(
                packageName: request['packageName'] as String? ?? '',
                username: request['username'] as String? ?? '',
                password: request['password'] as String? ?? '',
                onSave: _submitCreate,
                onDismiss: _cancel,
              ),
              _ => Center(
                child: Padding(
                  padding: const EdgeInsets.all(LockspireSpacing.lg),
                  child: Text(
                    'No se pudo entender el pedido de autocompletado.',
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            };
          },
        ),
      ),
    );
  }
}

class _GetCredentialView extends StatefulWidget {
  final Vault vault;
  final String packageName;
  final ValueChanged<VaultEntry> onPick;

  const _GetCredentialView({
    required this.vault,
    required this.packageName,
    required this.onPick,
  });

  @override
  State<_GetCredentialView> createState() => _GetCredentialViewState();
}

class _GetCredentialViewState extends State<_GetCredentialView> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final matched = matchEntriesForPackage(
      entries: widget.vault.entries,
      packageName: widget.packageName,
    );
    final query = _query.trim().toLowerCase();
    final entries = query.isEmpty
        ? matched
        : matched.where((e) => e.title.toLowerCase().contains(query)).toList();

    return Column(
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
              hintText: 'Buscar por título',
              prefixIcon: Icon(Icons.search),
            ),
            onChanged: (value) => setState(() => _query = value),
          ),
        ),
        Expanded(
          child: entries.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(LockspireSpacing.lg),
                    child: Text(
                      query.isEmpty
                          ? 'Todavía no guardaste ninguna contraseña en Lockspire.'
                          : 'No se encontraron resultados.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(
                    LockspireSpacing.lg,
                    LockspireSpacing.sm,
                    LockspireSpacing.lg,
                    LockspireSpacing.lg,
                  ),
                  itemCount: entries.length,
                  separatorBuilder: (_, _) =>
                      const SizedBox(height: LockspireSpacing.sm),
                  itemBuilder: (context, index) {
                    final entry = entries[index];
                    final username = entry.fields['username'];
                    return Material(
                      color: LockspireColors.bgSurface,
                      borderRadius: BorderRadius.circular(16),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: () => widget.onPick(entry),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: LockspireSpacing.md,
                            vertical: LockspireSpacing.smMd,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                entry.title,
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                              if (username != null && username.isNotEmpty)
                                Text(
                                  username,
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _CreateCredentialView extends StatelessWidget {
  final String packageName;
  final String username;
  final String password;
  final Future<void> Function({
    required String packageName,
    required String username,
    required String password,
  })
  onSave;
  final VoidCallback onDismiss;

  const _CreateCredentialView({
    required this.packageName,
    required this.username,
    required this.password,
    required this.onSave,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(LockspireSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '¿Guardar esta credencial en Lockspire?',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: LockspireSpacing.sm),
            Text(
              '$packageName — $username',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: LockspireSpacing.lg),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => onSave(
                  packageName: packageName,
                  username: username,
                  password: password,
                ),
                child: const Text('Guardar'),
              ),
            ),
            const SizedBox(height: LockspireSpacing.sm),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: onDismiss,
                child: const Text('No, gracias'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
