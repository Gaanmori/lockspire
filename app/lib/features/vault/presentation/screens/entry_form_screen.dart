// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Gabriel Ángel Montoya Rico

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../clipboard/presentation/providers/clipboard_guard_provider.dart';
import '../../../../design/lockspire_spacing.dart';
import '../../application/password_generation_settings.dart';
import '../../application/save_vault_use_case.dart';
import '../../domain/entities/entry_fields.dart';
import '../../domain/entities/vault_entry.dart';
import '../../domain/ports/word_list_port.dart';
import '../providers/word_list_port_provider.dart';
import '../vault_entries_controller.dart';
import '../widgets/entry_form_fields.dart';
import '../widgets/entry_type_sections.dart';
import '../widgets/field_history_section.dart';
import '../widgets/password_generator_panel.dart';
import '../widgets/password_strength_indicator.dart';
import '../widgets/entry_type_label.dart';

/// Formulario único de crear/editar una entrada — sin vista de detalle de
/// solo lectura separada (ver docs/STATE.md — Fase 5). [entry] nulo =
/// crear una de tipo [type]; no nulo = editar, precargado.
///
/// Muestra secciones según el tipo (contraseña, tarjeta, documento), los
/// sitios web y apps Android de la entrada y sus campos a medida (ADR
/// 0025). Al guardar conserva cualquier key que el formulario no maneje.
class EntryFormScreen extends ConsumerStatefulWidget {
  final VaultEntry? entry;
  final VaultEntryType type;

  const EntryFormScreen({
    super.key,
    this.entry,
    this.type = VaultEntryType.password,
  });

  @override
  ConsumerState<EntryFormScreen> createState() => _EntryFormScreenState();
}

class _EntryFormScreenState extends ConsumerState<EntryFormScreen> {
  final _formKey = GlobalKey<FormState>();

  late final VaultEntryType _type = widget.entry?.type ?? widget.type;
  late final Map<String, String> _initial = widget.entry?.fields ?? const {};

  /// Keys con campo propio en el formulario, según el tipo.
  late final Map<String, TextEditingController> _fixed = {
    for (final key in _fixedKeys)
      key: TextEditingController(text: _initial[key]),
  };

  List<String> get _fixedKeys => switch (_type) {
    VaultEntryType.card => const [
      EntryFields.cardNumber,
      EntryFields.cardHolder,
      EntryFields.cardExpiry,
      EntryFields.cardCvv,
      EntryFields.cardPin,
    ],
    VaultEntryType.document => const [
      EntryFields.docNumber,
      EntryFields.docName,
      EntryFields.docBirthDate,
      EntryFields.docIssued,
      EntryFields.docExpiry,
    ],
    _ => const [EntryFields.username, EntryFields.password],
  };

  late final _titleController = TextEditingController(
    text: widget.entry?.title ?? '',
  );
  late final _notesController = TextEditingController(
    text: _initial[EntryFields.notes] ?? '',
  );
  late final List<TextEditingController> _urls = () {
    final urls = repeatedValues(_initial, EntryFields.url);
    return [
      for (final url in urls) TextEditingController(text: url),
      // Una contraseña nueva arranca con un sitio vacío, listo para escribir.
      if (urls.isEmpty && _type == VaultEntryType.password)
        TextEditingController(),
    ];
  }();
  late final List<TextEditingController> _apps = [
    for (final app in repeatedValues(_initial, EntryFields.app))
      TextEditingController(text: app),
  ];
  late final List<CustomFieldDraft> _custom = [
    for (final field in customFieldsOf(_initial))
      CustomFieldDraft(
        name: field.name,
        hidden: field.hidden,
        value: field.value,
      ),
  ];

  final _passwordObscure = ValueNotifier(true);

  bool _saving = false;
  String? _errorMessage;

  late PasswordGenerationSettings _generation = widget.entry == null
      ? PasswordGenerationSettings.forNewEntry
      : PasswordGenerationSettings.fromFields(widget.entry!.fields);

  bool get _isEditing => widget.entry != null;

  TextEditingController get _passwordController =>
      _fixed[EntryFields.password]!;

  @override
  void dispose() {
    _titleController.dispose();
    _notesController.dispose();
    _passwordObscure.dispose();
    for (final controller in [
      ..._fixed.values,
      ..._urls,
      ..._apps,
      for (final draft in _custom) draft.value,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  /// Parte de las keys actuales para no perder las que el formulario no
  /// maneja, quita las que sí maneja y agrega lo que hay en pantalla.
  Map<String, String> _buildFields() {
    bool managed(String key) =>
        _fixed.containsKey(key) ||
        key == EntryFields.notes ||
        repeatedIndex(EntryFields.url, key) != null ||
        repeatedIndex(EntryFields.app, key) != null ||
        CustomField.fromEntry(key, '') != null ||
        key == PasswordGenerationSettings.modeFieldKey ||
        key == PasswordGenerationSettings.lengthFieldKey;

    return {
      for (final MapEntry(:key, :value) in _initial.entries)
        if (!managed(key)) key: value,
      for (final MapEntry(:key, value: controller) in _fixed.entries)
        if (controller.text.isNotEmpty) key: controller.text,
      ...repeatedFields(EntryFields.url, _urls.map((c) => c.text)),
      ...repeatedFields(EntryFields.app, _apps.map((c) => c.text)),
      for (final draft in _custom)
        if (draft.value.text.isNotEmpty)
          CustomField(
            name: draft.name,
            value: draft.value.text,
            hidden: draft.hidden,
          ).key: draft.value.text,
      if (_notesController.text.isNotEmpty)
        EntryFields.notes: _notesController.text,
      if (_type == VaultEntryType.password) ..._generation.toFields(),
    };
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _saving = true;
      _errorMessage = null;
    });

    final fields = _buildFields();

    try {
      final controller = ref.read(vaultEntriesControllerProvider);
      if (_isEditing) {
        await controller.updateEntry(
          id: widget.entry!.id,
          title: _titleController.text,
          fields: fields,
        );
      } else {
        await controller.addEntry(
          title: _titleController.text,
          type: _type,
          fields: fields,
        );
      }
      if (mounted) Navigator.of(context).pop();
    } on VaultWriteConflictException catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _errorMessage =
              '${e.toString()} Revise los datos e intente guardar de nuevo.';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _errorMessage = 'No se pudo guardar: $e';
        });
      }
    }
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('¿Eliminar esta entrada?'),
        content: Text('Se eliminará "${widget.entry!.title}" de la bóveda.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    await ref
        .read(vaultEntriesControllerProvider)
        .deleteEntry(widget.entry!.id);
    if (mounted) Navigator.of(context).pop();
  }

  /// Regenera la contraseña con [_generation] (ver
  /// `PasswordGenerationSettings`). En modo "fácil de recordar" se toman
  /// palabras de la wordlist del idioma real del sistema operativo
  /// (español si es `es`, inglés para cualquier otro idioma — decisión
  /// confirmada con el usuario, sin selector manual en la UI).
  ///
  /// **Se usa `PlatformDispatcher.instance.locale`, no
  /// `Localizations.localeOf(context)`**: la app no declara
  /// `supportedLocales`, así que la resolución de Flutter caía en silencio
  /// a `en_US` (bug real encontrado por el usuario con Windows en `es-CO`).
  Future<void> _regeneratePassword() async {
    final languageCode =
        WidgetsBinding.instance.platformDispatcher.locale.languageCode;
    final wordList = await ref
        .read(wordListPortProvider)
        .load(
          languageCode == 'es'
              ? WordListLanguage.spanish
              : WordListLanguage.english,
        );
    if (!mounted) return;
    _passwordController.text = _generation.generate(wordList: wordList);
    _passwordObscure.value = false;
  }

  /// Copia [value] como secreto: marcado como sensible donde la
  /// plataforma lo permite y borrado a los 30 s, al bloquear o al salir
  /// (ver `ClipboardGuard`, hallazgo S4).
  Future<void> _copyToClipboard(String label, String value) async {
    if (value.isEmpty) return;
    final guard = ref.read(clipboardGuardProvider);
    await guard.copy(value);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '$label copiado — se borra en ${guard.clearAfter.inSeconds} s '
            'o al bloquear',
          ),
        ),
      );
    }
  }

  void _addUrl() => setState(() => _urls.add(TextEditingController()));

  void _addApp() => setState(() => _apps.add(TextEditingController()));

  Future<void> _addCustom() async {
    final draft = await CustomFieldsEditor.askNew(
      context,
      taken: {for (final d in _custom) d.name},
    );
    if (draft != null && mounted) setState(() => _custom.add(draft));
  }

  String get _appBarTitle {
    if (_isEditing) return 'Editar ${_type.label}';
    return _type == VaultEntryType.document
        ? 'Nuevo documento'
        : 'Nueva ${_type.label}';
  }

  Widget _gap() => const SizedBox(height: LockspireSpacing.md);

  Widget _sectionTitle(String text) => Padding(
    padding: const EdgeInsets.only(
      top: LockspireSpacing.md,
      bottom: LockspireSpacing.sm,
    ),
    child: Text(text, style: Theme.of(context).textTheme.titleSmall),
  );

  List<Widget> _passwordSection() => [
    CopyableField(
      controller: _fixed[EntryFields.username]!,
      label: 'Usuario',
      onCopy: _copyToClipboard,
    ),
    _gap(),
    SecretField(
      controller: _passwordController,
      label: 'Contraseña',
      obscure: _passwordObscure,
      onCopy: _copyToClipboard,
      extraActions: [
        IconButton(
          icon: const Icon(Icons.casino_outlined),
          tooltip: 'Generar contraseña',
          onPressed: () => unawaited(_regeneratePassword()),
        ),
      ],
    ),
    const SizedBox(height: LockspireSpacing.sm),
    PasswordGeneratorPanel(
      settings: _generation,
      onChanged: (settings) {
        _generation = settings;
        unawaited(_regeneratePassword());
      },
    ),
    ValueListenableBuilder<TextEditingValue>(
      valueListenable: _passwordController,
      builder: (context, value, _) {
        if (value.text.isEmpty) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(top: LockspireSpacing.sm),
          child: PasswordStrengthIndicator(password: value.text),
        );
      },
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_appBarTitle),
        actions: [
          if (_isEditing)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: 'Eliminar',
              onPressed: _saving ? null : _delete,
            ),
        ],
      ),
      // Formulario simple, alineado arriba: el título ya está en la barra
      // (antes se repetía en una tarjeta con ícono que además le quitaba
      // ancho al teléfono — revisión de diseño 2026-09-29).
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(LockspireSpacing.lg),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextFormField(
                    controller: _titleController,
                    autofocus: !_isEditing,
                    decoration: const InputDecoration(labelText: 'Título'),
                    validator: (value) => (value == null || value.isEmpty)
                        ? 'Ingrese un título'
                        : null,
                  ),
                  _gap(),
                  ...switch (_type) {
                    VaultEntryType.card => [
                      CardFieldsSection(
                        fields: _fixed,
                        onCopy: _copyToClipboard,
                      ),
                    ],
                    VaultEntryType.document => [
                      DocumentFieldsSection(
                        fields: _fixed,
                        onCopy: _copyToClipboard,
                      ),
                    ],
                    _ => _passwordSection(),
                  },
                  // Cada sección aparece cuando tiene algo; vacías, se
                  // agregan desde la fila de botones de abajo.
                  if (_urls.isNotEmpty) ...[
                    _sectionTitle('Sitios web'),
                    RepeatedFieldList(
                      controllers: _urls,
                      label: 'Sitio web',
                      addLabel: 'Agregar sitio web',
                      hint: 'https://ejemplo.com/login',
                      icon: Icons.language,
                      keyboardType: TextInputType.url,
                      onCopy: _copyToClipboard,
                      onAdd: _addUrl,
                      onRemove: (i) =>
                          setState(() => _urls.removeAt(i).dispose()),
                    ),
                  ],
                  if (_apps.isNotEmpty) ...[
                    _sectionTitle('Apps Android'),
                    RepeatedFieldList(
                      controllers: _apps,
                      label: 'App (paquete)',
                      addLabel: 'Agregar app',
                      hint: 'com.ejemplo.app',
                      icon: Icons.android,
                      onCopy: _copyToClipboard,
                      onAdd: _addApp,
                      onRemove: (i) =>
                          setState(() => _apps.removeAt(i).dispose()),
                    ),
                  ],
                  if (_custom.isNotEmpty) ...[
                    _sectionTitle('Otros campos'),
                    CustomFieldsEditor(
                      drafts: _custom,
                      onCopy: _copyToClipboard,
                      onAdd: (draft) => setState(() => _custom.add(draft)),
                      onRemove: (i) =>
                          setState(() => _custom.removeAt(i).value.dispose()),
                    ),
                  ],
                  if (_urls.isEmpty || _apps.isEmpty || _custom.isEmpty) ...[
                    const SizedBox(height: LockspireSpacing.sm),
                    Wrap(
                      spacing: LockspireSpacing.sm,
                      children: [
                        if (_urls.isEmpty)
                          TextButton.icon(
                            onPressed: _addUrl,
                            icon: const Icon(Icons.add),
                            label: const Text('Sitio web'),
                          ),
                        if (_apps.isEmpty)
                          TextButton.icon(
                            onPressed: _addApp,
                            icon: const Icon(Icons.add),
                            label: const Text('App Android'),
                          ),
                        if (_custom.isEmpty)
                          TextButton.icon(
                            onPressed: _addCustom,
                            icon: const Icon(Icons.add),
                            label: const Text('Campo'),
                          ),
                      ],
                    ),
                  ],
                  _gap(),
                  TextFormField(
                    controller: _notesController,
                    decoration: const InputDecoration(labelText: 'Notas'),
                    minLines: 3,
                    maxLines: 8,
                  ),
                  if (widget.entry != null &&
                      widget.entry!.fieldHistory.isNotEmpty) ...[
                    _gap(),
                    FieldHistorySection(entry: widget.entry!),
                  ],
                  const SizedBox(height: LockspireSpacing.lg),
                  if (_errorMessage != null)
                    Padding(
                      padding: const EdgeInsets.only(
                        bottom: LockspireSpacing.md,
                      ),
                      child: Text(
                        _errorMessage!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  FilledButton(
                    onPressed: _saving ? null : _save,
                    child: _saving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Guardar'),
                  ),
                  const SizedBox(height: LockspireSpacing.sm),
                  Text(
                    'Se guarda cifrada junto con el resto de su bóveda.',
                    style: Theme.of(context).textTheme.bodySmall,
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
