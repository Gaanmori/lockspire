// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Gabriel Ángel Montoya Rico

import '../../../../design/readable_width.dart';
import 'package:flutter/material.dart';
import 'package:lockspire/l10n/l10n.dart';

/// Una opción de la sección Ajustes, que abre su propia pantalla.
class SettingsItem {
  final IconData icon;
  final String title;
  final String subtitle;
  final WidgetBuilder builder;

  const SettingsItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.builder,
  });
}

/// Un grupo de opciones con su título (General, Integraciones, Datos…).
/// [title] nulo: el grupo va sin título (p. ej. Acerca de, al final).
class SettingsSection {
  final String? title;
  final List<SettingsItem> items;

  const SettingsSection({this.title, required this.items});
}

/// Sección "Ajustes" de la navegación principal: opciones agrupadas por
/// tema que abren cada una su pantalla. Recibe los grupos desde fuera, así
/// que no depende de ninguna feature concreta. Un grupo sin opciones (p. ej.
/// sin integraciones en esta plataforma) no se muestra.
class SettingsScreen extends StatelessWidget {
  final List<SettingsSection> sections;

  const SettingsScreen({super.key, required this.sections});

  @override
  Widget build(BuildContext context) {
    final visible = [
      for (final section in sections)
        if (section.items.isNotEmpty) section,
    ];
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.settingsTitle)),
      body: ReadableWidth(
        child: ListView(
          children: [
            for (final (index, section) in visible.indexed) ...[
              if (index > 0) const Divider(),
              if (section.title case final title?)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ),
              for (final item in section.items)
                ListTile(
                  leading: Icon(item.icon),
                  title: Text(item.title),
                  subtitle: Text(item.subtitle),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.of(
                    context,
                  ).push(MaterialPageRoute(builder: item.builder)),
                ),
            ],
          ],
        ),
      ),
    );
  }
}
