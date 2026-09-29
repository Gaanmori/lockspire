// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Gabriel Ángel Montoya Rico

import 'package:flutter/material.dart';

import '../../../../design/lockspire_colors.dart';
import '../../../../design/lockspire_spacing.dart';
import '../../application/password_generation_settings.dart';

/// Panel del generador: modo (desplegable) y longitud (slider), el mismo
/// rango en los dos modos. El dado del campo contraseña siempre genera; acá
/// solo se eligen los parámetros. Cada cambio llama a [onChanged], y quien
/// lo usa regenera la contraseña.
class PasswordGeneratorPanel extends StatelessWidget {
  final PasswordGenerationSettings settings;
  final ValueChanged<PasswordGenerationSettings> onChanged;

  const PasswordGeneratorPanel({
    super.key,
    required this.settings,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: LockspireSpacing.smMd,
        vertical: LockspireSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: context.palette.bgSurfaceSubtle,
        borderRadius: BorderRadius.circular(LockspireRadius.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              DropdownButtonHideUnderline(
                child: DropdownButton<PasswordGenerationMode>(
                  value: settings.mode,
                  style: Theme.of(context).textTheme.bodyMedium,
                  items: const [
                    DropdownMenuItem(
                      value: PasswordGenerationMode.random,
                      child: Text('Aleatoria'),
                    ),
                    DropdownMenuItem(
                      value: PasswordGenerationMode.memorable,
                      child: Text('Fácil de recordar'),
                    ),
                  ],
                  onChanged: (mode) {
                    if (mode != null) onChanged(settings.copyWith(mode: mode));
                  },
                ),
              ),
              const SizedBox(width: LockspireSpacing.sm),
              Expanded(
                child: Slider(
                  value: settings.length.toDouble(),
                  min: PasswordGenerationSettings.minLength.toDouble(),
                  max: PasswordGenerationSettings.maxLength.toDouble(),
                  divisions:
                      PasswordGenerationSettings.maxLength -
                      PasswordGenerationSettings.minLength,
                  label: '${settings.length}',
                  onChanged: (value) =>
                      onChanged(settings.copyWith(length: value.round())),
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: LockspireSpacing.xs),
            child: Text(
              '${settings.length} caracteres',
              textAlign: TextAlign.right,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}
