// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Lockspire

import 'package:flutter/material.dart';

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

/// Sección "Ajustes" de la navegación principal: lista de opciones que
/// abren cada una su pantalla. Recibe las opciones desde fuera, así que no
/// depende de ninguna feature concreta.
class SettingsScreen extends StatelessWidget {
  final List<SettingsItem> items;

  const SettingsScreen({super.key, required this.items});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Ajustes')),
      body: ListView(
        children: [
          for (final item in items)
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
      ),
    );
  }
}
