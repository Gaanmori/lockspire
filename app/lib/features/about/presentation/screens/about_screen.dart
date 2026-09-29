// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Gabriel Ángel Montoya Rico

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../design/lockspire_icon.dart';
import '../../../../design/lockspire_spacing.dart';
import '../providers/about_providers.dart';
import 'package:lockspire/l10n/l10n.dart';

const _sourceUrl = 'https://github.com/Gaanmori/lockspire';
const _licenseUrl = 'https://www.gnu.org/licenses/agpl-3.0.html';
const _privacyUrl = 'https://gaanmori.github.io/lockspire/privacy-policy';
const _authorName = 'Gabriel Ángel Montoya Rico';
const _authorLinkedIn = 'https://www.linkedin.com/in/gabrielmontoyarico/';
const _authorGitHub = 'https://github.com/Gaanmori';

/// Versión, licencia y código fuente (ADR 0028). La AGPLv3 pide ofrecer el
/// código fuente a quien usa el programa; esta pantalla lo enlaza.
class AboutScreen extends ConsumerWidget {
  const AboutScreen({super.key});

  Future<void> _open(BuildContext context, WidgetRef ref, String url) async {
    final ok = await ref.read(externalLinkPortProvider).open(Uri.parse(url));
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.aboutOpenFailed(url))),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.aboutTitle)),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: ListView(
            padding: const EdgeInsets.all(LockspireSpacing.lg),
            children: [
              const Center(child: LockspireIcon(size: 88)),
              const SizedBox(height: LockspireSpacing.sm),
              Text(
                'Lockspire',
                style: textTheme.headlineSmall,
                textAlign: TextAlign.center,
              ),
              Text(
                switch (ref.watch(appVersionProvider).value) {
                  final v? => context.l10n.aboutVersion(v.version, v.build),
                  null => '',
                },
                style: textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: LockspireSpacing.md),
              Text(
                context.l10n.aboutTagline,
                style: textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: LockspireSpacing.lg),
              Card(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    LockspireSpacing.md,
                    LockspireSpacing.md,
                    LockspireSpacing.md,
                    LockspireSpacing.xs,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        context.l10n.aboutDevelopedBy,
                        style: textTheme.bodySmall,
                        textAlign: TextAlign.center,
                      ),
                      Text(
                        _authorName,
                        style: textTheme.titleMedium,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: LockspireSpacing.xs),
                      Text(
                        context.l10n.aboutAuthorLine,
                        style: textTheme.bodySmall,
                        textAlign: TextAlign.center,
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          TextButton.icon(
                            onPressed: () =>
                                _open(context, ref, _authorLinkedIn),
                            icon: const Icon(Icons.work_outline),
                            label: const Text('LinkedIn'),
                          ),
                          TextButton.icon(
                            onPressed: () => _open(context, ref, _authorGitHub),
                            icon: const Icon(Icons.code),
                            label: const Text('GitHub'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: LockspireSpacing.md),
              Card(
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.code),
                      title: Text(context.l10n.aboutSourceCode),
                      subtitle: const Text('github.com/Gaanmori/lockspire'),
                      trailing: const Icon(Icons.open_in_new),
                      onTap: () => _open(context, ref, _sourceUrl),
                    ),
                    ListTile(
                      leading: const Icon(Icons.gavel_outlined),
                      title: Text(context.l10n.aboutLicense),
                      subtitle: Text(context.l10n.aboutLicenseName),
                      trailing: const Icon(Icons.open_in_new),
                      onTap: () => _open(context, ref, _licenseUrl),
                    ),
                    ListTile(
                      leading: const Icon(Icons.privacy_tip_outlined),
                      title: Text(context.l10n.aboutPrivacyPolicy),
                      trailing: const Icon(Icons.open_in_new),
                      onTap: () => _open(context, ref, _privacyUrl),
                    ),
                    ListTile(
                      leading: const Icon(Icons.library_books_outlined),
                      title: Text(context.l10n.aboutThirdParty),
                      subtitle: Text(context.l10n.aboutThirdPartyHint),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => showLicensePage(
                        context: context,
                        applicationName: 'Lockspire',
                        applicationLegalese: context.l10n.aboutLegalese(
                          _authorName,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
