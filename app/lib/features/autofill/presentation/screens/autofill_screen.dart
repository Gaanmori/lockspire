// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Lockspire

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../design/lockspire_colors.dart';
import '../../../../design/lockspire_spacing.dart';
import '../../../vault/domain/entities/vault.dart';
import '../../../vault/domain/entities/entry_fields.dart';
import '../../../vault/domain/entities/vault_entry.dart';
import '../../../vault/presentation/vault_entries_controller.dart';
import '../../../browser_bridge/domain/origin_matcher.dart';
import '../../domain/autofill_web_origin.dart';
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

  /// "Rellenar y recordar este sitio" (ADR 0020): la entrada pasa a
  /// coincidir sola la próxima vez, igual que al vincular desde la
  /// extensión (ADR 0015).
  Future<void> _linkSiteAndSubmit(VaultEntry entry, String origin) async {
    await ref
        .read(vaultEntriesControllerProvider)
        .updateEntry(
          id: entry.id,
          title: entry.title,
          fields: {...entry.fields, 'url': linkedUrlForOrigin(origin)},
        );
    await _submitGet(entry);
  }

  /// Con página web, la entrada nueva se titula con el sitio y guarda su
  /// URL, en vez del paquete del navegador (ADR 0020).
  Future<void> _submitCreate({
    required String packageName,
    required String? origin,
    required String username,
    required String password,
  }) async {
    await ref
        .read(vaultEntriesControllerProvider)
        .addEntry(
          title: origin != null ? Uri.parse(origin).host : packageName,
          fields: {
            'username': username,
            'password': password,
            if (origin != null) 'url': linkedUrlForOrigin(origin),
          },
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
            final origin = webOriginFor(
              webDomain: request['webDomain'] as String?,
              webScheme: request['webScheme'] as String?,
            );
            return switch (request['mode']) {
              'get' => _GetCredentialView(
                vault: widget.vault,
                packageName: request['packageName'] as String? ?? '',
                origin: origin,
                onFill: _submitGet,
                onLinkAndFill: _linkSiteAndSubmit,
              ),
              'create' => _CreateCredentialView(
                packageName: request['packageName'] as String? ?? '',
                origin: origin,
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

  /// Sitio que pide (ADR 0020), o `null` si es una app nativa.
  final String? origin;
  final Future<void> Function(VaultEntry entry) onFill;
  final Future<void> Function(VaultEntry entry, String origin) onLinkAndFill;

  const _GetCredentialView({
    required this.vault,
    required this.packageName,
    required this.origin,
    required this.onFill,
    required this.onLinkAndFill,
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

  /// Sin página web se rellena directo, como antes (ADR 0011). Con
  /// página web decide la coincidencia con el sitio (ADR 0020).
  Future<void> _pick(VaultEntry entry) async {
    final origin = widget.origin;
    if (origin == null) return widget.onFill(entry);
    switch (classifyEntryForOrigin(entry, origin)) {
      case EntrySiteMatch.matches:
        return widget.onFill(entry);
      case EntrySiteMatch.otherSite:
        if (await _confirmOtherSite(entry, origin)) {
          return widget.onFill(entry);
        }
      case EntrySiteMatch.noSite:
        switch (await _askNoSite(entry, origin)) {
          case _NoSiteChoice.linkAndFill:
            return widget.onLinkAndFill(entry, origin);
          case _NoSiteChoice.fillOnce:
            return widget.onFill(entry);
          case _NoSiteChoice.cancel || null:
            return;
        }
    }
  }

  Future<bool> _confirmOtherSite(VaultEntry entry, String origin) async {
    final pageHost = Uri.parse(origin).host;
    final entrySite = entry.urls.join(', ');
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: Icon(
          Icons.warning_amber_rounded,
          color: Theme.of(context).colorScheme.error,
        ),
        title: const Text('¿Es el sitio correcto?'),
        content: Text(
          '"${entry.title}" es de $entrySite, pero la página que la pide es '
          '$pageHost.\n\n'
          'Si no esperaba este sitio, puede ser una página falsa que intenta '
          'robar su contraseña (phishing).',
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Rellenar igual'),
          ),
        ],
      ),
    );
    return confirmed ?? false;
  }

  Future<_NoSiteChoice?> _askNoSite(VaultEntry entry, String origin) =>
      showDialog<_NoSiteChoice>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Esta entrada no tiene sitio'),
          content: Text(
            '"${entry.title}" no tiene un sitio guardado, así que Lockspire '
            'no puede comprobar que ${Uri.parse(origin).host} sea el '
            'correcto.\n\n'
            'Si lo recuerda, la próxima vez se va a rellenar sola, y solo en '
            'este sitio.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(_NoSiteChoice.cancel),
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: () =>
                  Navigator.of(context).pop(_NoSiteChoice.fillOnce),
              child: const Text('Solo esta vez'),
            ),
            FilledButton(
              onPressed: () =>
                  Navigator.of(context).pop(_NoSiteChoice.linkAndFill),
              child: const Text('Rellenar y recordar'),
            ),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    final origin = widget.origin;
    final matched = origin != null
        ? sortEntriesForOrigin(entries: widget.vault.entries, origin: origin)
        : matchEntriesForPackage(
            entries: widget.vault.entries,
            packageName: widget.packageName,
          );
    final query = _query.trim().toLowerCase();
    final entries = query.isEmpty
        ? matched
        : matched.where((e) => e.title.toLowerCase().contains(query)).toList();

    return Column(
      children: [
        _RequesterHeader(packageName: widget.packageName, origin: origin),
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
                          ? 'Todavía no ha guardado ninguna contraseña en Lockspire.'
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
                    final sameSite =
                        origin != null &&
                        classifyEntryForOrigin(entry, origin) ==
                            EntrySiteMatch.matches;
                    return Material(
                      color: context.palette.bgSurface,
                      borderRadius: BorderRadius.circular(16),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: () => _pick(entry),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: LockspireSpacing.md,
                            vertical: LockspireSpacing.smMd,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      entry.title,
                                      style: Theme.of(
                                        context,
                                      ).textTheme.bodyMedium,
                                    ),
                                  ),
                                  if (sameSite)
                                    Icon(
                                      Icons.verified_outlined,
                                      size: 18,
                                      semanticLabel: 'Coincide con el sitio',
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.primary,
                                    ),
                                ],
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

enum _NoSiteChoice { linkAndFill, fillOnce, cancel }

/// Quién pide la credencial (ADR 0020): el sitio y la app que lo muestra,
/// para que el usuario note si no es el que esperaba.
class _RequesterHeader extends StatelessWidget {
  final String packageName;
  final String? origin;

  const _RequesterHeader({required this.packageName, required this.origin});

  @override
  Widget build(BuildContext context) {
    final origin = this.origin;
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        LockspireSpacing.lg,
        LockspireSpacing.md,
        LockspireSpacing.lg,
        0,
      ),
      child: Row(
        children: [
          Icon(
            origin != null ? Icons.language : Icons.apps,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(width: LockspireSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  origin != null
                      ? Uri.parse(origin).host
                      : (packageName.isEmpty ? 'App desconocida' : packageName),
                  style: theme.textTheme.titleMedium,
                ),
                Text(
                  origin != null
                      ? describeRequestingApp(packageName)
                      : 'App de Android',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CreateCredentialView extends StatelessWidget {
  final String packageName;
  final String? origin;
  final String username;
  final String password;
  final Future<void> Function({
    required String packageName,
    required String? origin,
    required String username,
    required String password,
  })
  onSave;
  final VoidCallback onDismiss;

  const _CreateCredentialView({
    required this.packageName,
    required this.origin,
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
              '${origin != null ? Uri.parse(origin!).host : packageName} — '
              '$username',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: LockspireSpacing.lg),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => onSave(
                  packageName: packageName,
                  origin: origin,
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
