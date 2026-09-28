// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Lockspire

import 'package:flutter/material.dart';

import '../../../../design/lockspire_spacing.dart';
import '../../application/password_generation_settings.dart';
import '../../domain/entities/vault_entry.dart';

/// Muestra los valores que un merge automático de Nivel 2 descartó por
/// esta entrada (ADR 0009) — solo lectura, sin botón de restaurar (no se
/// pidió esa funcionalidad, evita alcance extra). Nunca se pierde en
/// silencio un valor perdedor, pero tampoco molesta a nadie que nunca tuvo
/// un choque real: la sección entera no se muestra si `fieldHistory` está
/// vacío (ver el `if` en el `build()` de arriba).
class FieldHistorySection extends StatelessWidget {
  final VaultEntry entry;

  const FieldHistorySection({super.key, required this.entry});

  static String _displayName(String key) {
    if (key == titleFieldKey) return 'Título';
    return switch (key) {
      'username' => 'Usuario',
      'password' => 'Contraseña',
      'url' => 'URL',
      'notes' => 'Notas',
      PasswordGenerationSettings.modeFieldKey => 'Modo de generación',
      PasswordGenerationSettings.lengthFieldKey => 'Parámetro de generación',
      _ => key,
    };
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        title: const Text('Historial de cambios automáticos'),
        subtitle: const Text(
          'Un choque real entre dos dispositivos se resolvió solo — acá '
          'quedan los valores que no ganaron.',
        ),
        children: [
          for (final field in entry.fieldHistory.entries)
            Padding(
              padding: const EdgeInsets.only(bottom: LockspireSpacing.sm),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _displayName(field.key),
                    style: Theme.of(context).textTheme.labelMedium,
                  ),
                  for (final record in field.value)
                    Text(
                      // La contraseña nunca se muestra en texto plano acá
                      // — mismo criterio de seguridad que el campo del
                      // formulario, sin botón de "revelar" (fuera de
                      // alcance, no se pidió).
                      field.key == 'password'
                          ? '•••••••• — ${record.replacedAt.toLocal()}'
                          : '${record.value} — ${record.replacedAt.toLocal()}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
