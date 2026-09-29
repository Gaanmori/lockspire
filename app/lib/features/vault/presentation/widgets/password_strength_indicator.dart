// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Gabriel Ángel Montoya Rico

import 'package:flutter/material.dart';

import '../../../../design/lockspire_colors.dart';
import '../../../../design/lockspire_spacing.dart';
import '../../application/password_strength_estimator.dart';

/// Barra de fortaleza + tiempo estimado de descifrado (ver
/// `password_strength_estimator.dart`) — reacciona tanto a una
/// contraseña generada como a una tecleada a mano, sin distinguir entre
/// ambas (la estimación es solo por clases de caracteres presentes).
class PasswordStrengthIndicator extends StatelessWidget {
  final String password;

  const PasswordStrengthIndicator({super.key, required this.password});

  Color _colorFor(BuildContext context, PasswordStrengthLevel level) =>
      switch (level) {
        PasswordStrengthLevel.weak => context.palette.danger,
        PasswordStrengthLevel.fair => context.palette.accentDefault,
        PasswordStrengthLevel.strong => context.palette.accentSecondary,
      };

  String _labelFor(PasswordStrengthLevel level) => switch (level) {
    PasswordStrengthLevel.weak => 'Débil',
    PasswordStrengthLevel.fair => 'Regular',
    PasswordStrengthLevel.strong => 'Segura',
  };

  @override
  Widget build(BuildContext context) {
    final estimate = estimatePasswordStrength(password);
    final color = _colorFor(context, estimate.level);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(LockspireRadius.pill),
          child: LinearProgressIndicator(
            value: (estimate.bits / 100).clamp(0.0, 1.0),
            minHeight: 6,
            backgroundColor: context.palette.bgSurfaceSubtle,
            valueColor: AlwaysStoppedAnimation(color),
          ),
        ),
        const SizedBox(height: LockspireSpacing.xs),
        Text(
          '${_labelFor(estimate.level)} — tiempo estimado para '
          'descifrarla: ${estimate.crackTimeLabel}',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: color),
        ),
      ],
    );
  }
}
