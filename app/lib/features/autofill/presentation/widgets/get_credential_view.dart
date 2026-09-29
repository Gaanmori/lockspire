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
import 'package:lockspire/l10n/l10n.dart';

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
        title: Text(context.l10n.autofillWrongSiteTitle),
        content: Text(
          context.l10n.autofillWrongSiteBody(entry.title, entrySite, pageHost),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(context.l10n.commonCancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(context.l10n.autofillFillAnyway),
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
          title: Text(context.l10n.autofillNoSiteTitle),
          content: Text(
            context.l10n.autofillNoSiteBody(
              entry.title,
              Uri.parse(origin).host,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(_NoSiteChoice.cancel),
              child: Text(context.l10n.commonCancel),
            ),
            TextButton(
              onPressed: () =>
                  Navigator.of(context).pop(_NoSiteChoice.fillOnce),
              child: Text(context.l10n.autofillJustOnce),
            ),
            FilledButton(
              onPressed: () =>
                  Navigator.of(context).pop(_NoSiteChoice.linkAndFill),
              child: Text(context.l10n.autofillFillAndRemember),
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
            decoration: InputDecoration(
              hintText: context.l10n.autofillSearchHint,
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
                          ? context.l10n.autofillEmpty
                          : context.l10n.autofillNoResults,
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
                                      semanticLabel:
                                          context.l10n.autofillMatchesSite,
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
                      : (packageName.isEmpty
                            ? context.l10n.autofillUnknownApp
                            : packageName),
                  style: theme.textTheme.titleMedium,
                ),
                Text(
                  origin != null
                      ? _requestingApp(context.l10n, packageName)
                      : context.l10n.autofillAndroidApp,
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

/// Quién muestra la página: "en Chrome" o "dentro de la app com.ejemplo".
String _requestingApp(AppLocalizations l10n, String packageName) {
  final browser = knownBrowserName(packageName);
  if (browser != null) return l10n.autofillInBrowser(browser);
  if (packageName.isEmpty) return l10n.autofillInUnknownApp;
  return l10n.autofillInsideApp(packageName);
}
