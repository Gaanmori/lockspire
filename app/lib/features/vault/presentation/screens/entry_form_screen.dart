// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Lockspire

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../design/lockspire_colors.dart';
import '../../../clipboard/presentation/providers/clipboard_guard_provider.dart';
import '../../../../design/lockspire_spacing.dart';
import '../../application/memorable_wordlists.dart';
import '../../application/password_generator.dart';
import '../../application/password_strength_estimator.dart';
import '../../application/save_vault_use_case.dart';
import '../../domain/entities/vault_entry.dart';
import '../vault_entries_controller.dart';
import '../widgets/auth_card.dart';

/// Modo de generación elegido en el panel del generador — ver
/// `_buildPasswordGeneratorPanel`.
enum _PasswordGenerationMode { random, memorable }

// Se guardan como campos más dentro de `fields` (mismo criterio que
// `username`/`password`/`url`/`notes` — no hay jerarquía de subclases,
// ver `vault_entry.dart`) para que, al editar, el panel arranque con el
// modo/parámetro que se usó la última vez y "generar otra" reproduzca el
// mismo estilo sin que el usuario tenga que volver a elegirlo. No son
// datos sensibles (solo dicen *cómo* se generó, no la contraseña en sí).
const _genModeFieldKey = 'password_gen_mode';
const _genParamFieldKey = 'password_gen_param';

// Un solo rango de longitud para los dos modos — el usuario pidió que
// "fácil de recordar" también se controle por cantidad de caracteres
// (no por cantidad de palabras), igual que el modo aleatorio, para
// tener precisión real cuando un sitio exige un máximo/mínimo de
// caracteres. `generateMemorablePassword` agrega palabras completas
// mientras entren sin superar el objetivo (ver `password_generator.dart`).
const _passwordLengthRange = (min: 8.0, max: 48.0, divisions: 40);

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

  late _PasswordGenerationMode _passwordMode;
  late double _passwordLength;

  bool get _isEditing => widget.entry != null;

  @override
  void initState() {
    super.initState();

    final storedMode = widget.entry?.fields[_genModeFieldKey];
    final storedLength = double.tryParse(
      widget.entry?.fields[_genParamFieldKey] ?? '',
    );

    switch (storedMode) {
      case 'random':
        _passwordMode = _PasswordGenerationMode.random;
        _passwordLength = storedLength ?? 20;
      case 'memorable':
        _passwordMode = _PasswordGenerationMode.memorable;
        _passwordLength = storedLength ?? 20;
      default:
        if (_isEditing) {
          // Entrada existente sin metadata de generación (creada antes de
          // esta feature, o importada de SafeInCloud) — no hay forma de
          // saber cómo se hizo la contraseña guardada, así que se infiere
          // aleatoria con su longitud actual (así "generar otra" da algo
          // de un porte similar, en vez de sorprender con un valor fijo).
          _passwordMode = _PasswordGenerationMode.random;
          _passwordLength = (widget.entry!.fields['password']?.length ?? 20)
              .clamp(
                _passwordLengthRange.min.round(),
                _passwordLengthRange.max.round(),
              )
              .toDouble();
        } else {
          // Crear una entrada nueva: "fácil de recordar" por default,
          // pedido explícito del usuario — si elige aleatoria, queda esa
          // elección para lo que reste de esta sesión de edición.
          _passwordMode = _PasswordGenerationMode.memorable;
          _passwordLength = 20;
        }
    }
  }

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
      _genModeFieldKey: _passwordMode.name,
      _genParamFieldKey: _passwordLength.round().toString(),
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
        .read(vaultEntriesControllerProvider)
        .deleteEntry(widget.entry!.id);
    if (mounted) Navigator.of(context).pop();
  }

  /// Regenera la contraseña según [_passwordMode], ambos apuntando a
  /// [_passwordLength] caracteres (mismo control en los dos modos —
  /// pedido explícito del usuario, para tener precisión real cuando un
  /// sitio exige un máximo/mínimo de caracteres). En modo "fácil de
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
  void _regeneratePassword() {
    final languageCode =
        WidgetsBinding.instance.platformDispatcher.locale.languageCode;
    final wordList = languageCode == 'es' ? spanishWordList : englishWordList;
    final length = _passwordLength.round();

    setState(() {
      _passwordController.text = switch (_passwordMode) {
        _PasswordGenerationMode.random => generatePassword(length: length),
        _PasswordGenerationMode.memorable => generateMemorablePassword(
          wordList: wordList,
          targetLength: length,
        ),
      };
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
                              onPressed: _regeneratePassword,
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
                    _buildPasswordGeneratorPanel(),
                    ValueListenableBuilder<TextEditingValue>(
                      valueListenable: _passwordController,
                      builder: (context, value, _) {
                        if (value.text.isEmpty) return const SizedBox.shrink();
                        return Padding(
                          padding: const EdgeInsets.only(
                            top: LockspireSpacing.sm,
                          ),
                          child: _PasswordStrengthIndicator(
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

  /// Controles de generación, **siempre visibles** (no un panel
  /// colapsable — el usuario reportó que esconder/mostrar según el ícono
  /// de dado resultaba confuso, porque el dado a veces generaba y a
  /// veces solo abría el panel). El dado del campo contraseña ahora
  /// siempre genera de una ([_regeneratePassword] directo, ver arriba);
  /// acá vive la elección de modo (desplegable) y el slider de
  /// longitud — mismo rango en los dos modos, ver [_passwordLength].
  Widget _buildPasswordGeneratorPanel() {
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
                child: DropdownButton<_PasswordGenerationMode>(
                  value: _passwordMode,
                  style: Theme.of(context).textTheme.bodyMedium,
                  items: const [
                    DropdownMenuItem(
                      value: _PasswordGenerationMode.random,
                      child: Text('Aleatoria'),
                    ),
                    DropdownMenuItem(
                      value: _PasswordGenerationMode.memorable,
                      child: Text('Fácil de recordar'),
                    ),
                  ],
                  onChanged: (mode) {
                    if (mode == null) return;
                    setState(() => _passwordMode = mode);
                    _regeneratePassword();
                  },
                ),
              ),
              const SizedBox(width: LockspireSpacing.sm),
              Expanded(
                child: Slider(
                  value: _passwordLength,
                  min: _passwordLengthRange.min,
                  max: _passwordLengthRange.max,
                  divisions: _passwordLengthRange.divisions,
                  label: '${_passwordLength.round()}',
                  onChanged: (value) {
                    _passwordLength = value;
                    _regeneratePassword();
                  },
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: LockspireSpacing.xs),
            child: Text(
              '${_passwordLength.round()} caracteres',
              textAlign: TextAlign.right,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}

/// Barra de fortaleza + tiempo estimado de descifrado (ver
/// `password_strength_estimator.dart`) — reacciona tanto a una
/// contraseña generada como a una tecleada a mano, sin distinguir entre
/// ambas (la estimación es solo por clases de caracteres presentes).
class _PasswordStrengthIndicator extends StatelessWidget {
  final String password;

  const _PasswordStrengthIndicator({required this.password});

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
      _genModeFieldKey => 'Modo de generación',
      _genParamFieldKey => 'Parámetro de generación',
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
