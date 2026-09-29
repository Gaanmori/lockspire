// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Gabriel Ángel Montoya Rico

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../design/lockspire_colors.dart';
import '../../domain/entities/entry_fields.dart';
import '../../domain/entities/vault_entry.dart';
import '../../domain/site_icons.dart';
import '../providers/installed_app_icon_provider.dart';
import 'entry_type_label.dart';

/// Ícono redondo de una entrada (ADR 0029), en este orden: el del sitio
/// (si se activaron los íconos y ya se descargó), el de la app instalada
/// (Android) o una letra. Tarjetas y documentos, su símbolo.
class EntryAvatar extends ConsumerWidget {
  final VaultEntry entry;

  /// El ícono del sitio de la entrada, ya decodificado, o `null`.
  final Uint8List? siteIcon;
  final double size;

  const EntryAvatar({
    super.key,
    required this.entry,
    this.siteIcon,
    this.size = 40,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    Widget circle(Widget child, {Color? color}) => Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: color ?? palette.bgSurfaceSubtle,
        shape: BoxShape.circle,
      ),
      child: child,
    );
    // Fondo blanco detrás de los íconos: muchos son transparentes y
    // pensados para fondo claro.
    Widget image(Uint8List bytes) => circle(
      Padding(
        padding: EdgeInsets.all(size * 0.18),
        child: Image.memory(
          bytes,
          gaplessPlayback: true,
          filterQuality: FilterQuality.medium,
          errorBuilder: (_, _, _) => const SizedBox.shrink(),
        ),
      ),
      color: Colors.white,
    );

    if (entry.type != VaultEntryType.password) {
      return circle(
        Icon(entry.type.icon, size: size / 2, color: palette.accentDefault),
      );
    }
    final site = siteIcon;
    if (site != null) return image(site);

    final apps = entry.apps;
    if (apps.isNotEmpty) {
      final appIcon = ref.watch(installedAppIconProvider(apps.first)).value;
      if (appIcon != null) return image(appIcon);
    }
    return circle(
      Text(
        entryInitial(entry),
        style: TextStyle(
          color: palette.accentDefault,
          fontWeight: FontWeight.w700,
          fontSize: size * 0.4,
        ),
      ),
    );
  }
}
