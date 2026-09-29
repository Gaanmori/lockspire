// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Gabriel Ángel Montoya Rico

import 'package:flutter/material.dart';

import '../../../../design/lockspire_spacing.dart';

/// Copia un valor como secreto (ver `ClipboardGuard`). La pantalla que usa
/// estos campos decide cómo avisar.
typedef CopyValue = Future<void> Function(String label, String value);

/// Campo de texto con botón de copiar.
class CopyableField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String? hint;
  final CopyValue onCopy;
  final TextInputType? keyboardType;
  final Widget? leading;

  const CopyableField({
    super.key,
    required this.controller,
    required this.label,
    required this.onCopy,
    this.hint,
    this.keyboardType,
    this.leading,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: leading,
        suffixIcon: IconButton(
          icon: const Icon(Icons.copy_outlined),
          tooltip: 'Copiar ${label.toLowerCase()}',
          onPressed: () => onCopy(label, controller.text),
        ),
      ),
    );
  }
}

/// Campo oculto por defecto (contraseña, número de tarjeta, CVV, PIN…),
/// con mostrar/ocultar y copiar. [extraActions] va antes de esos botones
/// (por ejemplo, el generador de contraseñas).
class SecretField extends StatefulWidget {
  final TextEditingController controller;
  final String label;
  final String? hint;
  final CopyValue onCopy;
  final TextInputType? keyboardType;
  final List<Widget> extraActions;

  /// Para que quien genera un valor pueda mostrarlo al instante.
  final ValueNotifier<bool>? obscure;

  const SecretField({
    super.key,
    required this.controller,
    required this.label,
    required this.onCopy,
    this.hint,
    this.keyboardType,
    this.extraActions = const [],
    this.obscure,
  });

  @override
  State<SecretField> createState() => _SecretFieldState();
}

class _SecretFieldState extends State<SecretField> {
  late final ValueNotifier<bool> _obscure =
      widget.obscure ?? ValueNotifier(true);

  @override
  void dispose() {
    if (widget.obscure == null) _obscure.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: _obscure,
      builder: (context, obscure, _) => TextFormField(
        controller: widget.controller,
        obscureText: obscure,
        keyboardType: widget.keyboardType,
        decoration: InputDecoration(
          labelText: widget.label,
          hintText: widget.hint,
          suffixIcon: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              ...widget.extraActions,
              IconButton(
                icon: Icon(obscure ? Icons.visibility : Icons.visibility_off),
                tooltip: obscure ? 'Mostrar' : 'Ocultar',
                onPressed: () => _obscure.value = !obscure,
              ),
              IconButton(
                icon: const Icon(Icons.copy_outlined),
                tooltip: 'Copiar ${widget.label.toLowerCase()}',
                onPressed: () =>
                    widget.onCopy(widget.label, widget.controller.text),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Lista de valores del mismo tipo (sitios web, apps Android): cada uno
/// con su campo y botón de quitar, y un botón para agregar otro.
class RepeatedFieldList extends StatelessWidget {
  final List<TextEditingController> controllers;
  final String label;
  final String addLabel;
  final String? hint;
  final IconData icon;
  final TextInputType? keyboardType;
  final CopyValue onCopy;
  final VoidCallback onAdd;
  final void Function(int index) onRemove;

  const RepeatedFieldList({
    super.key,
    required this.controllers,
    required this.label,
    required this.addLabel,
    required this.icon,
    required this.onCopy,
    required this.onAdd,
    required this.onRemove,
    this.hint,
    this.keyboardType,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (index, controller) in controllers.indexed) ...[
          Row(
            children: [
              Expanded(
                child: CopyableField(
                  controller: controller,
                  label: controllers.length == 1
                      ? label
                      : '$label ${index + 1}',
                  hint: hint,
                  keyboardType: keyboardType,
                  leading: Icon(icon),
                  onCopy: onCopy,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.remove_circle_outline),
                tooltip: 'Quitar',
                onPressed: () => onRemove(index),
              ),
            ],
          ),
          const SizedBox(height: LockspireSpacing.sm),
        ],
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add),
            label: Text(addLabel),
          ),
        ),
      ],
    );
  }
}

/// Borrador editable de un campo a medida (ADR 0025).
class CustomFieldDraft {
  final String name;
  final bool hidden;
  final TextEditingController value;

  CustomFieldDraft({
    required this.name,
    required this.hidden,
    required String value,
  }) : value = TextEditingController(text: value);
}

/// Campos a medida de la entrada: los existentes, editables y con quitar,
/// y "Agregar campo" que pide nombre y si es oculto.
class CustomFieldsEditor extends StatelessWidget {
  final List<CustomFieldDraft> drafts;
  final CopyValue onCopy;
  final void Function(CustomFieldDraft draft) onAdd;
  final void Function(int index) onRemove;

  const CustomFieldsEditor({
    super.key,
    required this.drafts,
    required this.onCopy,
    required this.onAdd,
    required this.onRemove,
  });

  /// Pide nombre y si es oculto para un campo nuevo; `null` si se cancela.
  static Future<CustomFieldDraft?> askNew(
    BuildContext context, {
    required Set<String> taken,
  }) => showDialog<CustomFieldDraft>(
    context: context,
    builder: (_) => _NewCustomFieldDialog(taken: taken),
  );

  Future<void> _askNew(BuildContext context) async {
    final draft = await askNew(
      context,
      taken: {for (final d in drafts) d.name},
    );
    if (draft != null) onAdd(draft);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (index, draft) in drafts.indexed) ...[
          Row(
            children: [
              Expanded(
                child: draft.hidden
                    ? SecretField(
                        controller: draft.value,
                        label: draft.name,
                        onCopy: onCopy,
                      )
                    : CopyableField(
                        controller: draft.value,
                        label: draft.name,
                        onCopy: onCopy,
                      ),
              ),
              IconButton(
                icon: const Icon(Icons.remove_circle_outline),
                tooltip: 'Quitar campo',
                onPressed: () => onRemove(index),
              ),
            ],
          ),
          const SizedBox(height: LockspireSpacing.sm),
        ],
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () => _askNew(context),
            icon: const Icon(Icons.add),
            label: const Text('Agregar campo'),
          ),
        ),
      ],
    );
  }
}

class _NewCustomFieldDialog extends StatefulWidget {
  final Set<String> taken;

  const _NewCustomFieldDialog({required this.taken});

  @override
  State<_NewCustomFieldDialog> createState() => _NewCustomFieldDialogState();
}

class _NewCustomFieldDialogState extends State<_NewCustomFieldDialog> {
  final _name = TextEditingController();
  bool _hidden = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _name.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Ingrese un nombre');
      return;
    }
    if (widget.taken.contains(name)) {
      setState(() => _error = 'Ya hay un campo con ese nombre');
      return;
    }
    Navigator.of(
      context,
    ).pop(CustomFieldDraft(name: name, hidden: _hidden, value: ''));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Nuevo campo'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _name,
            autofocus: true,
            decoration: InputDecoration(
              labelText: 'Nombre del campo',
              hintText: 'Por ejemplo: Pregunta secreta',
              errorText: _error,
            ),
            onSubmitted: (_) => _submit(),
          ),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            value: _hidden,
            onChanged: (value) => setState(() => _hidden = value ?? false),
            title: const Text('Ocultar el valor'),
            subtitle: const Text('Para claves, PIN y otros datos sensibles'),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(onPressed: _submit, child: const Text('Agregar')),
      ],
    );
  }
}
