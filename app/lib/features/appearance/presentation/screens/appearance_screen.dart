// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Lockspire

import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../design/lockspire_colors.dart';
import '../../../../design/lockspire_spacing.dart';
import '../../../../design/lockspire_theme.dart';
import '../../domain/appearance_preference.dart';
import '../appearance_controller.dart';
import '../appearance_theme.dart';
import '../providers/system_accent_color_provider.dart';

/// Elegir familia de colores (Cálido, Menta, Lavanda) y modo (según el
/// sistema, claro u oscuro). El cambio se aplica al instante.
class AppearanceScreen extends ConsumerWidget {
  const AppearanceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final preference =
        ref.watch(appearanceControllerProvider).value ??
        AppearancePreference.defaults;
    final controller = ref.read(appearanceControllerProvider.notifier);
    final systemArgb = ref.watch(systemAccentColorProvider).value;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Apariencia')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(LockspireSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Modo', style: textTheme.titleMedium),
              const SizedBox(height: LockspireSpacing.sm),
              SegmentedButton<AppearanceMode>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(
                    value: AppearanceMode.system,
                    icon: Icon(Icons.brightness_auto_outlined),
                    label: Text('Sistema'),
                  ),
                  ButtonSegment(
                    value: AppearanceMode.light,
                    icon: Icon(Icons.light_mode_outlined),
                    label: Text('Claro'),
                  ),
                  ButtonSegment(
                    value: AppearanceMode.dark,
                    icon: Icon(Icons.dark_mode_outlined),
                    label: Text('Oscuro'),
                  ),
                ],
                selected: {preference.mode},
                onSelectionChanged: (selection) =>
                    controller.setMode(selection.first),
              ),
              const SizedBox(height: LockspireSpacing.xs),
              Text(
                preference.mode == AppearanceMode.system
                    ? 'Cambia sola entre claro y oscuro según tu sistema.'
                    : ' ',
                style: textTheme.bodySmall,
              ),
              const SizedBox(height: LockspireSpacing.lg),
              Text('Tema', style: textTheme.titleMedium),
              const SizedBox(height: LockspireSpacing.sm),
              for (final family in ThemeFamilyId.values) ...[
                _FamilyCard(
                  title: _titleFor(family),
                  subtitle: _subtitleFor(family, systemArgb),
                  palettes: palettesFor(family, systemArgb),
                  selected: preference.family == family,
                  onTap: () => controller.setFamily(family),
                ),
                const SizedBox(height: LockspireSpacing.smMd),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

String _titleFor(ThemeFamilyId family) => switch (family) {
  ThemeFamilyId.sistema => 'Colores del sistema',
  ThemeFamilyId.lineage ||
  ThemeFamilyId.calido ||
  ThemeFamilyId.menta ||
  ThemeFamilyId.lavanda =>
    LockspireThemeFamily.values.byName(family.name).displayName,
};

String? _subtitleFor(ThemeFamilyId family, int? systemArgb) => switch (family) {
  ThemeFamilyId.sistema when systemArgb == null =>
    'No disponible en este equipo: se usa Lineage.',
  ThemeFamilyId.sistema =>
    Platform.isAndroid
        ? 'Material You: colores de tu fondo de pantalla.'
        : 'Color de acento del sistema.',
  _ => null,
};

class _FamilyCard extends StatelessWidget {
  final String title;
  final String? subtitle;
  final PalettePair palettes;
  final bool selected;
  final VoidCallback onTap;

  const _FamilyCard({
    required this.title,
    required this.subtitle,
    required this.palettes,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Semantics(
      selected: selected,
      button: true,
      label: 'Tema $title',
      child: Material(
        color: palette.bgSurface,
        borderRadius: BorderRadius.circular(LockspireRadius.md),
        child: InkWell(
          borderRadius: BorderRadius.circular(LockspireRadius.md),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(LockspireSpacing.smMd),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(LockspireRadius.md),
              border: Border.all(
                color: selected
                    ? palette.accentDefault
                    : palette.bgSurfaceSubtle,
                width: selected ? 2 : 1,
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _Preview(palette: palettes.light, label: 'Claro'),
                ),
                const SizedBox(width: LockspireSpacing.sm),
                Expanded(
                  child: _Preview(palette: palettes.dark, label: 'Oscuro'),
                ),
                const SizedBox(width: LockspireSpacing.smMd),
                SizedBox(
                  width: 120,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      if (subtitle != null)
                        Text(
                          subtitle!,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      if (selected)
                        Row(
                          children: [
                            Icon(
                              Icons.check_circle,
                              size: 16,
                              color: palette.accentDefault,
                            ),
                            const SizedBox(width: LockspireSpacing.xs),
                            Text(
                              'En uso',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Miniatura de una pantalla con los colores de [palette]: fila de lista,
/// campo y botón.
class _Preview extends StatelessWidget {
  final LockspirePalette palette;
  final String label;

  const _Preview({required this.palette, required this.label});

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: Container(
        padding: const EdgeInsets.all(LockspireSpacing.sm),
        decoration: BoxDecoration(
          color: palette.bgPage,
          borderRadius: BorderRadius.circular(LockspireRadius.sm),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: palette.textSecondary,
              ),
            ),
            const SizedBox(height: 6),
            Container(
              height: 18,
              decoration: BoxDecoration(
                color: palette.bgSurface,
                borderRadius: BorderRadius.circular(6),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 6),
              alignment: Alignment.centerLeft,
              child: Container(
                width: 34,
                height: 5,
                color: palette.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Container(
              height: 12,
              decoration: BoxDecoration(
                color: palette.bgInput,
                borderRadius: BorderRadius.circular(6),
              ),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Container(
                  width: 34,
                  height: 12,
                  decoration: BoxDecoration(
                    color: palette.accentDefault,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                const SizedBox(width: 4),
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: palette.accentSecondary,
                    shape: BoxShape.circle,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
