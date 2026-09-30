// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Gabriel Ángel Montoya Rico

import 'package:flutter/material.dart';
import 'package:lockspire/l10n/l10n.dart';

import '../../../../design/lockspire_spacing.dart';
import '../../application/password_generation_settings.dart';
import 'entry_form_fields.dart';
import 'password_generator_panel.dart';
import 'password_strength_indicator.dart';

/// Usuario, contraseña, generador y fortaleza de una entrada de tipo
/// contraseña (revisión 2026-09-30, A15: antes vivía en la pantalla).
class PasswordEntrySection extends StatelessWidget {
  final TextEditingController username;
  final TextEditingController password;
  final ValueNotifier<bool> obscure;
  final PasswordGenerationSettings generation;

  /// El usuario cambió el modo o el largo del generador.
  final ValueChanged<PasswordGenerationSettings> onGenerationChanged;

  /// Generar otra contraseña con los ajustes actuales.
  final VoidCallback onRegenerate;

  final Future<void> Function(String label, String value) onCopy;

  const PasswordEntrySection({
    super.key,
    required this.username,
    required this.password,
    required this.obscure,
    required this.generation,
    required this.onGenerationChanged,
    required this.onRegenerate,
    required this.onCopy,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CopyableField(
          controller: username,
          label: context.l10n.fieldUsername,
          onCopy: onCopy,
        ),
        const SizedBox(height: LockspireSpacing.md),
        SecretField(
          controller: password,
          label: context.l10n.fieldPassword,
          obscure: obscure,
          onCopy: onCopy,
          extraActions: [
            IconButton(
              icon: const Icon(Icons.casino_outlined),
              tooltip: context.l10n.entryGeneratePassword,
              onPressed: onRegenerate,
            ),
          ],
        ),
        const SizedBox(height: LockspireSpacing.sm),
        PasswordGeneratorPanel(
          settings: generation,
          onChanged: onGenerationChanged,
        ),
        ValueListenableBuilder<TextEditingValue>(
          valueListenable: password,
          builder: (context, value, _) {
            if (value.text.isEmpty) return const SizedBox.shrink();
            return Padding(
              padding: const EdgeInsets.only(top: LockspireSpacing.sm),
              child: PasswordStrengthIndicator(password: value.text),
            );
          },
        ),
      ],
    );
  }
}
