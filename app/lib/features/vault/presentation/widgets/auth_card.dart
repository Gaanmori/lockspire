// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Lockspire

import 'package:flutter/material.dart';

import '../../../../design/lockspire_colors.dart';
import '../../../../design/lockspire_icon.dart';
import '../../../../design/lockspire_spacing.dart';

/// Tarjeta de autenticación (crear/desbloquear bóveda): chip de icono +
/// título + subtítulo + contenido, sobre superficie elevada. Sigue el
/// mockup "Desbloquear bóveda" / "Crear bóveda" del canvas de diseño
/// (ver docs/design/README.md).
class AuthCard extends StatelessWidget {
  final IconData icon;

  /// El ícono de Lockspire (con los colores del tema) en vez de [icon]:
  /// para las pantallas de entrada a la app, crear y desbloquear la bóveda.
  final bool brand;
  final String title;
  final String subtitle;
  final Widget child;

  const AuthCard({
    super.key,
    required this.icon,
    this.brand = false,
    required this.title,
    required this.subtitle,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: LockspireSpacing.lg,
        vertical: LockspireSpacing.xl,
      ),
      decoration: BoxDecoration(
        color: context.palette.bgSurface,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: context.palette.textPrimary.withValues(alpha: 0.06),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: brand
                ? const LockspireIcon(size: 72)
                : Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: context.palette.bgSurfaceSubtle,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Icon(
                      icon,
                      size: 28,
                      color: context.palette.accentDefault,
                    ),
                  ),
          ),
          const SizedBox(height: LockspireSpacing.mdLg),
          Text(
            title,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: LockspireSpacing.xs),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: LockspireSpacing.lg),
          child,
        ],
      ),
    );
  }
}
