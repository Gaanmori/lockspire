// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Lockspire

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../design/lockspire_spacing.dart';
import '../../application/password_generator.dart';
import '../../application/save_vault_use_case.dart';
import '../../domain/entities/vault_entry.dart';
import '../vault_session_controller.dart';
import '../widgets/auth_card.dart';

const _clipboardAutoClear = Duration(seconds: 30);

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
    };

    try {
      final controller = ref.read(vaultSessionControllerProvider.notifier);
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
              '${e.toString()} Revisá los datos e intentá guardar de nuevo.';
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
        .read(vaultSessionControllerProvider.notifier)
        .deleteEntry(widget.entry!.id);
    if (mounted) Navigator.of(context).pop();
  }

  void _generatePassword() {
    setState(() {
      _passwordController.text = generatePassword();
      _obscure = false;
    });
  }

  /// Copia [value] y lo borra del portapapeles a los 30s **solo si sigue
  /// siendo exactamente ese valor** — cada copia se verifica contra su
  /// propio contenido capturado por closure, nunca contra un flag
  /// compartido de "hay un timer pendiente". Así, copiar dos campos
  /// seguidos no hace que el primer timer borre lo que copió el segundo.
  Future<void> _copyToClipboard(String label, String value) async {
    if (value.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: value));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$label copiado — se borra en 30s')),
      );
    }
    Timer(_clipboardAutoClear, () async {
      final current = await Clipboard.getData(Clipboard.kTextPlain);
      if (current?.text == value) {
        await Clipboard.setData(const ClipboardData(text: ''));
      }
    });
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
                subtitle: 'Se guarda cifrada junto con el resto de tu bóveda.',
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: _titleController,
                      autofocus: !_isEditing,
                      decoration: const InputDecoration(labelText: 'Título'),
                      validator: (value) => (value == null || value.isEmpty)
                          ? 'Ingresá un título'
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
                              onPressed: _generatePassword,
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
                      _FieldHistorySection(entry: widget.entry!),
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

/// Muestra los valores que un merge automático de Nivel 2 descartó por
/// esta entrada (ADR 0009) — solo lectura, sin botón de restaurar (no se
/// pidió esa funcionalidad, evita alcance extra). Nunca se pierde en
/// silencio un valor perdedor, pero tampoco molesta a nadie que nunca tuvo
/// un choque real: la sección entera no se muestra si `fieldHistory` está
/// vacío (ver el `if` en el `build()` de arriba).
class _FieldHistorySection extends StatelessWidget {
  final VaultEntry entry;

  const _FieldHistorySection({required this.entry});

  static String _displayName(String key) {
    if (key == titleFieldKey) return 'Título';
    return switch (key) {
      'username' => 'Usuario',
      'password' => 'Contraseña',
      'url' => 'URL',
      'notes' => 'Notas',
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
