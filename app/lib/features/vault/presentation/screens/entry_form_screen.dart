// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Lockspire

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../clipboard/presentation/providers/clipboard_guard_provider.dart';
import '../../../../design/lockspire_spacing.dart';
import '../../application/password_generation_settings.dart';
import '../../application/save_vault_use_case.dart';
import '../../domain/entities/vault_entry.dart';
import '../../domain/ports/word_list_port.dart';
import '../providers/word_list_port_provider.dart';
import '../vault_entries_controller.dart';
import '../widgets/auth_card.dart';
import '../widgets/field_history_section.dart';
import '../widgets/password_generator_panel.dart';
import '../widgets/password_strength_indicator.dart';

/// Formulario único de crear/editar una entrada de contraseña — sin vista
/// de detalle de solo lectura separada (ver docs/STATE.md — Fase 5).
/// [entry] nulo = crear; no nulo = editar, precargado.
class EntryFormScreen extends ConsumerStatefulWidget {
  final VaultEntry? entry;

  const EntryFormScreen({super.key, this.entry});

  @override
  ConsumerState<EntryFormScreen> createState() => _EntryFormScreenState();
}

class _EntryFormScreenState extends ConsumerState<EntryFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final _titleController = TextEditingController(
    text: widget.entry?.title ?? '',
  );
  late final _usernameController = TextEditingController(
    text: widget.entry?.fields['username'] ?? '',
  );
  late final _passwordController = TextEditingController(
    text: widget.entry?.fields['password'] ?? '',
  );
  late final _urlController = TextEditingController(
    text: widget.entry?.fields['url'] ?? '',
  );
  late final _notesController = TextEditingController(
    text: widget.entry?.fields['notes'] ?? '',
  );

  bool _obscure = true;
  bool _saving = false;
  String? _errorMessage;

  late PasswordGenerationSettings _generation = widget.entry == null
      ? PasswordGenerationSettings.forNewEntry
      : PasswordGenerationSettings.fromFields(widget.entry!.fields);

  bool get _isEditing => widget.entry != null;

  @override
  void dispose() {
    _titleController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _urlController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _saving = true;
      _errorMessage = null;
    });

    final fields = {
      'username': _usernameController.text,
      'password': _passwordController.text,
      'url': _urlController.text,
      'notes': _notesController.text,
      ..._generation.toFields(),
    };

    try {
      final controller = ref.read(vaultEntriesControllerProvider);
      if (_isEditing) {
        await controller.updateEntry(
          id: widget.entry!.id,
          title: _titleController.text,
          fields: fields,
        );
      } else {
        await controller.addEntry(title: _titleController.text, fields: fields);
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
  /// `PasswordGenerationSettings`). En modo "fácil de
  /// recordar" se toman palabras de la wordlist que corresponda al
  /// idioma real del sistema operativo (español si es `es`, inglés para
  /// cualquier otro idioma — decisión confirmada con el usuario, sin
  /// selector manual en la UI).
  ///
  /// **Se usa `PlatformDispatcher.instance.locale`, no
  /// `Localizations.localeOf(context)`** — a propósito, no por
  /// descuido: esta app no tiene un sistema de i18n real (todo el texto
  /// está hardcodeado en español), así que `MaterialApp` nunca declaró
  /// `supportedLocales`. Sin eso, el algoritmo de resolución de Flutter
  /// no tiene con qué hacer *match* contra el idioma real del sistema y
  /// cae en silencio al único locale que sabe manejar (`en_US`) — bug
  /// real encontrado por el usuario (Windows en `es-CO`, la app
  /// generaba en inglés igual). `PlatformDispatcher.instance.locale`
  /// devuelve el locale que reporta el sistema operativo directo, sin
  /// pasar por esa resolución.
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
    setState(() {
      _passwordController.text = _generation.generate(wordList: wordList);
      _obscure = false;
    });
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

  String get _appBarTitle =>
      _isEditing ? 'Editar contraseña' : 'Nueva contraseña';

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
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(LockspireSpacing.lg),
            child: Form(
              key: _formKey,
              child: AuthCard(
                icon: Icons.key_outlined,
                title: _appBarTitle,
                subtitle: 'Se guarda cifrada junto con el resto de su bóveda.',
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: _titleController,
                      autofocus: !_isEditing,
                      decoration: const InputDecoration(labelText: 'Título'),
                      validator: (value) => (value == null || value.isEmpty)
                          ? 'Ingrese un título'
                          : null,
                    ),
                    const SizedBox(height: LockspireSpacing.md),
                    TextFormField(
                      controller: _usernameController,
                      decoration: InputDecoration(
                        labelText: 'Usuario',
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.copy_outlined),
                          tooltip: 'Copiar usuario',
                          onPressed: () => _copyToClipboard(
                            'Usuario',
                            _usernameController.text,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: LockspireSpacing.md),
                    TextFormField(
                      controller: _passwordController,
                      obscureText: _obscure,
                      decoration: InputDecoration(
                        labelText: 'Contraseña',
                        suffixIcon: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.casino_outlined),
                              tooltip: 'Generar contraseña',
                              onPressed: () => unawaited(_regeneratePassword()),
                            ),
                            IconButton(
                              icon: Icon(
                                _obscure
                                    ? Icons.visibility
                                    : Icons.visibility_off,
                              ),
                              tooltip: _obscure ? 'Mostrar' : 'Ocultar',
                              onPressed: () =>
                                  setState(() => _obscure = !_obscure),
                            ),
                            IconButton(
                              icon: const Icon(Icons.copy_outlined),
                              tooltip: 'Copiar contraseña',
                              onPressed: () => _copyToClipboard(
                                'Contraseña',
                                _passwordController.text,
                              ),
                            ),
                          ],
                        ),
                      ),
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
                          padding: const EdgeInsets.only(
                            top: LockspireSpacing.sm,
                          ),
                          child: PasswordStrengthIndicator(
                            password: value.text,
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: LockspireSpacing.md),
                    TextFormField(
                      controller: _urlController,
                      decoration: const InputDecoration(labelText: 'URL'),
                      keyboardType: TextInputType.url,
                    ),
                    const SizedBox(height: LockspireSpacing.md),
                    TextFormField(
                      controller: _notesController,
                      decoration: const InputDecoration(labelText: 'Notas'),
                      // 8 en vez de 3: una entrada importada de SafeInCloud
                      // puede traer varias líneas transicionales (TOTP,
                      // PIN, tarjeta) además del texto libre — con 3 no se
                      // veían sin hacer scroll dentro del campo (el dato
                      // seguía completo, solo estaba recortado a la
                      // vista).
                      maxLines: 8,
                    ),
                    if (widget.entry != null &&
                        widget.entry!.fieldHistory.isNotEmpty) ...[
                      const SizedBox(height: LockspireSpacing.md),
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
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: _saving ? null : _save,
                        child: _saving
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text('Guardar'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
