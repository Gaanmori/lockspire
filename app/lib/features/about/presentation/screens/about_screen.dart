// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Lockspire

import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../design/lockspire_icon.dart';
import '../../../../design/lockspire_spacing.dart';

const _sourceUrl = 'https://github.com/Gaanmori/lockspire';
const _licenseUrl = 'https://www.gnu.org/licenses/agpl-3.0.html';
const _privacyUrl = 'https://gaanmori.github.io/lockspire/privacy-policy';

/// Versión, licencia y código fuente (ADR 0028). La AGPLv3 pide ofrecer el
/// código fuente a quien usa el programa; esta pantalla lo enlaza.
class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  Future<void> _open(BuildContext context, String url) async {
    final ok = await launchUrl(
      Uri.parse(url),
      mode: LaunchMode.externalApplication,
    );
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('No se pudo abrir $url')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Acerca de')),
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
              FutureBuilder<PackageInfo>(
                future: PackageInfo.fromPlatform(),
                builder: (context, snapshot) {
                  final info = snapshot.data;
                  return Text(
                    info == null
                        ? ''
                        : 'Versión ${info.version} (${info.buildNumber})',
                    style: textTheme.bodySmall,
                    textAlign: TextAlign.center,
                  );
                },
              ),
              const SizedBox(height: LockspireSpacing.md),
              Text(
                'Gestor de contraseñas libre y local. Su bóveda se cifra en su '
                'dispositivo y solo se sincroniza con la nube que usted '
                'elija. Sin publicidad, sin analíticas y sin servidores '
                'propios.',
                style: textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: LockspireSpacing.lg),
              Card(
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.code),
                      title: const Text('Código fuente'),
                      subtitle: const Text('github.com/Gaanmori/lockspire'),
                      trailing: const Icon(Icons.open_in_new),
                      onTap: () => _open(context, _sourceUrl),
                    ),
                    ListTile(
                      leading: const Icon(Icons.gavel_outlined),
                      title: const Text('Licencia'),
                      subtitle: const Text(
                        'GNU Affero General Public License v3 o posterior',
                      ),
                      trailing: const Icon(Icons.open_in_new),
                      onTap: () => _open(context, _licenseUrl),
                    ),
                    ListTile(
                      leading: const Icon(Icons.privacy_tip_outlined),
                      title: const Text('Política de privacidad'),
                      trailing: const Icon(Icons.open_in_new),
                      onTap: () => _open(context, _privacyUrl),
                    ),
                    ListTile(
                      leading: const Icon(Icons.library_books_outlined),
                      title: const Text('Licencias de terceros'),
                      subtitle: const Text(
                        'Componentes de código abierto que usa Lockspire',
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => showLicensePage(
                        context: context,
                        applicationName: 'Lockspire',
                        applicationLegalese:
                            'Copyright (C) 2026 Lockspire. Distribuido bajo '
                            'la GNU AGPL v3 o posterior.',
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
