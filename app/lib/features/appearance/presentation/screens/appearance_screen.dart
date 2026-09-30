// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Gabriel Ángel Montoya Rico

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lockspire/shared/platform_capabilities.dart';

import '../../../../design/lockspire_colors.dart';
import '../../../../design/lockspire_spacing.dart';
import '../../../../design/lockspire_theme.dart';
import '../../domain/appearance_preference.dart';
import '../appearance_controller.dart';
import '../appearance_theme.dart';
import '../providers/system_accent_color_provider.dart';
import 'package:lockspire/l10n/l10n.dart';

/// Elegir idioma (ADR 0032), familia de colores (Lineage, Pixel, Ubuntu,
/// Linux Mint, Windows 11) y modo (según el sistema, claro u oscuro). El
/// cambio se aplica al instante.
///
/// [extraSections] van al final, cada una tras un separador: secciones de
/// otras features que también son de apariencia, como los íconos de los
/// sitios. Las pone `app_shell.dart`, así esta pantalla no depende de ellas.
class AppearanceScreen extends ConsumerWidget {
  final List<Widget> extraSections;

  const AppearanceScreen({super.key, this.extraSections = const []});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final preference =
        ref.watch(appearanceControllerProvider).value ??
        AppearancePreference.defaults;
    final controller = ref.read(appearanceControllerProvider.notifier);
    final systemArgb = ref.watch(systemAccentColorProvider).value;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.appearanceTitle)),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(LockspireSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                context.l10n.appearanceLanguage,
                style: textTheme.titleMedium,
              ),
              const SizedBox(height: LockspireSpacing.sm),
              SegmentedButton<AppLanguage>(
                showSelectedIcon: false,
                segments: [
                  ButtonSegment(
                    value: AppLanguage.system,
                    icon: const Icon(Icons.language_outlined),
                    label: Text(context.l10n.appearanceModeSystem),
                  ),
                  // Los idiomas se muestran en su propio idioma, para que se
                  // encuentren aunque la app esté en otro.
                  const ButtonSegment(
                    value: AppLanguage.es,
                    label: Text('Español'),
                  ),
                  const ButtonSegment(
                    value: AppLanguage.en,
                    label: Text('English'),
                  ),
                ],
                selected: {preference.language},
                onSelectionChanged: (selection) =>
                    controller.setLanguage(selection.first),
              ),
              const SizedBox(height: LockspireSpacing.lg),
              Text(context.l10n.appearanceMode, style: textTheme.titleMedium),
              const SizedBox(height: LockspireSpacing.sm),
              SegmentedButton<AppearanceMode>(
                showSelectedIcon: false,
                segments: [
                  ButtonSegment(
                    value: AppearanceMode.system,
                    icon: Icon(Icons.brightness_auto_outlined),
                    label: Text(context.l10n.appearanceModeSystem),
                  ),
                  ButtonSegment(
                    value: AppearanceMode.light,
                    icon: Icon(Icons.light_mode_outlined),
                    label: Text(context.l10n.appearanceModeLight),
                  ),
                  ButtonSegment(
                    value: AppearanceMode.dark,
                    icon: Icon(Icons.dark_mode_outlined),
                    label: Text(context.l10n.appearanceModeDark),
                  ),
                ],
                selected: {preference.mode},
                onSelectionChanged: (selection) =>
                    controller.setMode(selection.first),
              ),
              const SizedBox(height: LockspireSpacing.xs),
              Text(
                preference.mode == AppearanceMode.system
                    ? context.l10n.appearanceModeSystemHint
                    : ' ',
                style: textTheme.bodySmall,
              ),
              const SizedBox(height: LockspireSpacing.lg),
              Text(context.l10n.appearanceTheme, style: textTheme.titleMedium),
              if (ref.watch(platformCapabilitiesProvider).isAndroid) ...[
                const SizedBox(height: LockspireSpacing.xs),
                // ADR 0031: el ícono del lanzador sigue al tema.
                Text(
                  context.l10n.appearanceLauncherIconNote,
                  style: textTheme.bodySmall,
                ),
              ],
              const SizedBox(height: LockspireSpacing.sm),
              for (final family in ThemeFamilyId.values) ...[
                _FamilyCard(
                  title: _titleFor(context.l10n, family),
                  subtitle: _subtitleFor(
                    context.l10n,
                    family,
                    systemArgb,
                    isAndroid: ref
                        .watch(platformCapabilitiesProvider)
                        .isAndroid,
                  ),
                  palettes: palettesFor(family, systemArgb),
                  selected: preference.family == family,
                  onTap: () => controller.setFamily(family),
                ),
                const SizedBox(height: LockspireSpacing.smMd),
              ],
              for (final section in extraSections) ...[
                const Divider(height: LockspireSpacing.xl),
                section,
              ],
            ],
          ),
        ),
      ),
    );
  }
}

String _titleFor(AppLocalizations l10n, ThemeFamilyId family) =>
    switch (family) {
      ThemeFamilyId.sistema => l10n.themeSystemColors,
      ThemeFamilyId.lineage ||
      ThemeFamilyId.pixel ||
      ThemeFamilyId.ubuntu ||
      ThemeFamilyId.mint ||
      ThemeFamilyId.windows =>
        LockspireThemeFamily.values.byName(family.name).displayName,
    };

String? _subtitleFor(
  AppLocalizations l10n,
  ThemeFamilyId family,
  int? systemArgb, {
  required bool isAndroid,
}) => switch (family) {
  ThemeFamilyId.sistema when systemArgb == null => l10n.themeSystemUnavailable,
  ThemeFamilyId.sistema =>
    isAndroid ? l10n.themeSystemAndroid : l10n.themeSystemDesktop,
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
      label: context.l10n.appearanceThemeSemantics(title),
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
                  child: _Preview(
                    palette: palettes.light,
                    label: context.l10n.appearanceModeLight,
                  ),
                ),
                const SizedBox(width: LockspireSpacing.sm),
                Expanded(
                  child: _Preview(
                    palette: palettes.dark,
                    label: context.l10n.appearanceModeDark,
                  ),
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
                              context.l10n.appearanceInUse,
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
