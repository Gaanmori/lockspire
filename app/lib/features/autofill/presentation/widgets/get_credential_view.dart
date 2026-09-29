// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Gabriel Ángel Montoya Rico

import 'package:flutter/material.dart';
import '../../../../design/lockspire_colors.dart';
import '../../../../design/lockspire_spacing.dart';
import '../../../vault/domain/entities/vault.dart';
import '../../../vault/domain/entities/entry_fields.dart';
import '../../../vault/domain/entities/vault_entry.dart';
import '../../domain/autofill_web_origin.dart';
import '../../domain/match_entries_for_package.dart';

/// Elegir qué cuenta rellenar (ADR 0011/0020): lista ordenada por
/// coincidencia con la app o el sitio, y avisos de sitio distinto o sin
/// sitio guardado.
class GetCredentialView extends StatefulWidget {
  final Vault vault;
  final String packageName;

  /// Sitio que pide (ADR 0020), o `null` si es una app nativa.
  final String? origin;
  final Future<void> Function(VaultEntry entry) onFill;
  final Future<void> Function(VaultEntry entry, String origin) onLinkAndFill;

  const GetCredentialView({
    super.key,
    required this.vault,
    required this.packageName,
    required this.origin,
    required this.onFill,
    required this.onLinkAndFill,
  });

  @override
  State<GetCredentialView> createState() => GetCredentialViewState();
}

class GetCredentialViewState extends State<GetCredentialView> {
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
        RequesterHeader(packageName: widget.packageName, origin: origin),
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
class RequesterHeader extends StatelessWidget {
  final String packageName;
  final String? origin;

  const RequesterHeader({
    super.key,
    required this.packageName,
    required this.origin,
  });

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
