// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Gabriel Ángel Montoya Rico

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../clipboard/presentation/providers/clipboard_guard_provider.dart';
import '../../../../design/lockspire_spacing.dart';
import '../../application/save_vault_use_case.dart';
import '../../domain/entities/entry_fields.dart';
import '../../domain/entities/vault_entry.dart';
import '../providers/word_list_port_provider.dart';
import '../entry_form_model.dart';
import '../vault_entries_controller.dart';
import '../widgets/entry_form_fields.dart';
import '../widgets/entry_type_sections.dart';
import '../widgets/field_history_section.dart';
import '../widgets/password_entry_section.dart';
import 'package:lockspire/l10n/l10n.dart';
import 'package:lockspire/l10n/localized_error.dart';
import 'package:lockspire/shared/presentation/navigation.dart';

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

  late final _form = EntryFormModel(entry: widget.entry, type: widget.type);

  final _passwordObscure = ValueNotifier(true);

  bool _saving = false;
  String? _errorMessage;

  bool get _isEditing => widget.entry != null;

  @override
  void dispose() {
    _form.dispose();
    _passwordObscure.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _saving = true;
      _errorMessage = null;
    });

    final fields = _form.toFields();

    try {
      final controller = ref.read(vaultEntriesControllerProvider);
      if (_isEditing) {
        await controller.updateEntry(
          id: widget.entry!.id,
          title: _form.title.text,
          fields: fields,
        );
      } else {
        await controller.addEntry(
          title: _form.title.text,
          type: _form.type,
          fields: fields,
        );
      }
      if (mounted) popIfCurrent(context);
    } on VaultWriteConflictException catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _errorMessage = context.l10n.entryConflict(
            localizeError(context.l10n, e),
          );
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _errorMessage = context.l10n.entrySaveFailed(
            localizeError(context.l10n, e),
          );
        });
      }
    }
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.l10n.entryDeleteTitle),
        content: Text(context.l10n.entryDeleteBody(widget.entry!.title)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(context.l10n.commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(context.l10n.commonDelete),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    await ref
        .read(vaultEntriesControllerProvider)
        .deleteEntry(widget.entry!.id);
    if (mounted) popIfCurrent(context);
  }

  /// Regenera la contraseña con [_form.generation] (ver
  /// `PasswordGenerationSettings`). En modo "fácil de recordar" las palabras
  /// salen siempre de la lista en inglés, sea cual sea el idioma de la app
  /// (ADR 0032): la española daba frases más débiles y el usuario pidió
  /// dejar solo la inglesa.
  Future<void> _regeneratePassword() async {
    final wordList = await ref.read(wordListPortProvider).load();
    if (!mounted) return;
    _form.password.text = _form.generation.generate(wordList: wordList);
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
            context.l10n.entryCopied(label, guard.clearAfter.inSeconds),
          ),
        ),
      );
    }
  }

  void _addUrl() => setState(() => _form.urls.add(TextEditingController()));

  void _addApp() => setState(() => _form.apps.add(TextEditingController()));

  Future<void> _addCustom() async {
    final draft = await CustomFieldsEditor.askNew(
      context,
      taken: {for (final d in _form.custom) d.name},
    );
    if (draft != null && mounted) setState(() => _form.custom.add(draft));
  }

  String get _appBarTitle => _isEditing
      ? context.l10n.entryEditTitle(_form.type.name)
      : context.l10n.entryNewTitle(_form.type.name);

  Widget _gap() => const SizedBox(height: LockspireSpacing.md);

  Widget _sectionTitle(String text) => Padding(
    padding: const EdgeInsets.only(
      top: LockspireSpacing.md,
      bottom: LockspireSpacing.sm,
    ),
    child: Text(text, style: Theme.of(context).textTheme.titleSmall),
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_appBarTitle),
        actions: [
          if (_isEditing)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: context.l10n.commonDelete,
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
                    controller: _form.title,
                    autofocus: !_isEditing,
                    decoration: InputDecoration(
                      labelText: context.l10n.fieldTitle,
                    ),
                    validator: (value) => (value == null || value.isEmpty)
                        ? context.l10n.entryTitleRequired
                        : null,
                  ),
                  _gap(),
                  ...switch (_form.type) {
                    VaultEntryType.card => [
                      CardFieldsSection(
                        fields: _form.fixed,
                        onCopy: _copyToClipboard,
                      ),
                    ],
                    VaultEntryType.document => [
                      DocumentFieldsSection(
                        fields: _form.fixed,
                        onCopy: _copyToClipboard,
                      ),
                    ],
                    _ => [
                      PasswordEntrySection(
                        username: _form.fixed[EntryFields.username]!,
                        password: _form.password,
                        obscure: _passwordObscure,
                        generation: _form.generation,
                        onGenerationChanged: (settings) {
                          // setState: sin él la contraseña se regeneraba con
                          // el largo nuevo, pero el slider y el "N
                          // caracteres" seguían mostrando el viejo.
                          setState(() => _form.generation = settings);
                          unawaited(_regeneratePassword());
                        },
                        onRegenerate: () => unawaited(_regeneratePassword()),
                        onCopy: _copyToClipboard,
                      ),
                    ],
                  },
                  // Cada sección aparece cuando tiene algo; vacías, se
                  // agregan desde la fila de botones de abajo.
                  if (_form.urls.isNotEmpty) ...[
                    _sectionTitle(context.l10n.entryWebsites),
                    RepeatedFieldList(
                      controllers: _form.urls,
                      label: context.l10n.fieldWebsite,
                      addLabel: context.l10n.entryAddWebsite,
                      hint: 'https://ejemplo.com/login',
                      icon: Icons.language,
                      keyboardType: TextInputType.url,
                      onCopy: _copyToClipboard,
                      onAdd: _addUrl,
                      onRemove: (i) =>
                          setState(() => _form.urls.removeAt(i).dispose()),
                    ),
                  ],
                  if (_form.apps.isNotEmpty) ...[
                    _sectionTitle(context.l10n.entryAndroidApps),
                    RepeatedFieldList(
                      controllers: _form.apps,
                      label: context.l10n.entryAppPackage,
                      addLabel: context.l10n.entryAddApp,
                      hint: 'com.ejemplo.app',
                      icon: Icons.android,
                      onCopy: _copyToClipboard,
                      onAdd: _addApp,
                      onRemove: (i) =>
                          setState(() => _form.apps.removeAt(i).dispose()),
                    ),
                  ],
                  if (_form.custom.isNotEmpty) ...[
                    _sectionTitle(context.l10n.entryOtherFields),
                    CustomFieldsEditor(
                      drafts: _form.custom,
                      onCopy: _copyToClipboard,
                      onAdd: (draft) => setState(() => _form.custom.add(draft)),
                      onRemove: (i) => setState(
                        () => _form.custom.removeAt(i).value.dispose(),
                      ),
                    ),
                  ],
                  if (_form.urls.isEmpty ||
                      _form.apps.isEmpty ||
                      _form.custom.isEmpty) ...[
                    const SizedBox(height: LockspireSpacing.sm),
                    Wrap(
                      spacing: LockspireSpacing.sm,
                      children: [
                        if (_form.urls.isEmpty)
                          TextButton.icon(
                            onPressed: _addUrl,
                            icon: const Icon(Icons.add),
                            label: Text(context.l10n.fieldWebsite),
                          ),
                        if (_form.apps.isEmpty)
                          TextButton.icon(
                            onPressed: _addApp,
                            icon: const Icon(Icons.add),
                            label: Text(context.l10n.entryAndroidApp),
                          ),
                        if (_form.custom.isEmpty)
                          TextButton.icon(
                            onPressed: _addCustom,
                            icon: const Icon(Icons.add),
                            label: Text(context.l10n.entryField),
                          ),
                      ],
                    ),
                  ],
                  _gap(),
                  TextFormField(
                    controller: _form.notes,
                    decoration: InputDecoration(
                      labelText: context.l10n.fieldNotes,
                    ),
                    minLines: 3,
                    maxLines: 8,
                  ),
                  if (widget.entry != null &&
                      widget.entry!.fieldHistory.isNotEmpty) ...[
                    _gap(),
                    FieldHistorySection(
                      entry: widget.entry!,
                      onCopy: _copyToClipboard,
                    ),
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
                        : Text(context.l10n.commonSave),
                  ),
                  const SizedBox(height: LockspireSpacing.sm),
                  Text(
                    context.l10n.entrySavedEncrypted,
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
