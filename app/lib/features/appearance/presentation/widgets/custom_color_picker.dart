// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Gabriel Ángel Montoya Rico

import 'package:flutter/material.dart';
import 'package:lockspire/l10n/l10n.dart';

import '../../../../design/lockspire_spacing.dart';

/// Colores sugeridos para el tema Personalizado: un recorrido por el círculo
/// cromático, con tonos que dan paletas legibles en claro y oscuro.
const suggestedCustomColors = <int>[
  0xFFD32F2F, // rojo
  0xFFC2185B, // rosa
  0xFF7B1FA2, // morado
  0xFF6750A4, // violeta
  0xFF3949AB, // índigo
  0xFF1E88E5, // azul
  0xFF00838F, // cian
  0xFF00897B, // verde azulado
  0xFF43A047, // verde
  0xFF9E9D24, // oliva
  0xFFFFB300, // ámbar
  0xFFF4511E, // naranja
  0xFF6D4C41, // marrón
  0xFF546E7A, // gris azulado
];

/// `#RRGGBB` (con o sin `#`) → ARGB opaco, o `null` si no es un color.
int? parseHexColor(String text) {
  final hex = text.trim().replaceFirst('#', '');
  if (!RegExp(r'^[0-9a-fA-F]{6}$').hasMatch(hex)) return null;
  return 0xFF000000 | int.parse(hex, radix: 16);
}

String hexOf(int argb) =>
    '#${(argb & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';

/// Elegir el color del tema Personalizado (ADR 0036): uno de los sugeridos o
/// cualquiera escrito en hexadecimal. La paleta completa (clara y oscura) la
/// genera el algoritmo tonal de Material 3 a partir de ese color.
class CustomColorPicker extends StatefulWidget {
  final int selected;
  final ValueChanged<int> onPick;

  const CustomColorPicker({
    super.key,
    required this.selected,
    required this.onPick,
  });

  @override
  State<CustomColorPicker> createState() => _CustomColorPickerState();
}

class _CustomColorPickerState extends State<CustomColorPicker> {
  late final _hex = TextEditingController(text: hexOf(widget.selected));
  String? _error;

  @override
  void didUpdateWidget(CustomColorPicker old) {
    super.didUpdateWidget(old);
    if (old.selected != widget.selected) _hex.text = hexOf(widget.selected);
  }

  @override
  void dispose() {
    _hex.dispose();
    super.dispose();
  }

  void _applyHex() {
    final argb = parseHexColor(_hex.text);
    setState(
      () => _error = argb == null ? context.l10n.themeCustomInvalid : null,
    );
    if (argb != null) widget.onPick(argb);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: LockspireSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: LockspireSpacing.sm,
            runSpacing: LockspireSpacing.sm,
            children: [
              for (final argb in suggestedCustomColors)
                Tooltip(
                  message: hexOf(argb),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: () => widget.onPick(argb),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Color(argb),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: argb == widget.selected
                              ? scheme.onSurface
                              : Colors.transparent,
                          width: 3,
                        ),
                      ),
                      child: argb == widget.selected
                          ? const Icon(Icons.check, color: Colors.white)
                          : null,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: LockspireSpacing.md),
          TextField(
            controller: _hex,
            decoration: InputDecoration(
              labelText: context.l10n.themeCustomHex,
              hintText: '#6750A4',
              errorText: _error,
              prefixIcon: Padding(
                padding: const EdgeInsets.all(12),
                child: Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    color: Color(widget.selected),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
              suffixIcon: IconButton(
                icon: const Icon(Icons.check),
                tooltip: context.l10n.themeCustomApply,
                onPressed: _applyHex,
              ),
            ),
            onSubmitted: (_) => _applyHex(),
          ),
        ],
      ),
    );
  }
}
