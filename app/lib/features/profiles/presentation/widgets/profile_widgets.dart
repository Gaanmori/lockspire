// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Gabriel Ángel Montoya Rico

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lockspire/l10n/l10n.dart';
import 'package:lockspire/l10n/localized_error.dart';
import 'package:lockspire/shared/domain/app_problem.dart';
import 'package:lockspire/shared/secure_storage_provider.dart';

import '../../domain/profile.dart';
import '../../domain/profile_registry.dart';
import '../profiles_controller.dart';

/// El nombre para mostrar: el principal sin nombre propio es "Principal"
/// en el idioma de la app.
String profileDisplayName(BuildContext context, Profile profile) =>
    profile.name.isEmpty && profile.isMain
    ? context.l10n.profilesMainName
    : profile.name;

/// La lista de perfiles encima de desbloquear y crear la bóveda (ADR
/// 0039). Solo aparece si los perfiles están activados y hay más de uno.
class ProfilePicker extends ConsumerWidget {
  const ProfilePicker({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(showsProfilePickerProvider)) return const SizedBox.shrink();
    final registry = ref.watch(profilesControllerProvider).value;
    if (registry == null) return const SizedBox.shrink();
    final activeId = ref.watch(activeProfileIdProvider);
    final controller = ref.read(profilesControllerProvider.notifier);
    return Semantics(
      container: true,
      label: context.l10n.profilesPickerLabel,
      child: Wrap(
        alignment: WrapAlignment.center,
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final profile in registry.profiles)
            ChoiceChip(
              avatar: const Icon(Icons.person_outline, size: 18),
              label: Text(profileDisplayName(context, profile)),
              selected: profile.id == activeId,
              onSelected: (_) => controller.open(profile.id),
            ),
          ActionChip(
            avatar: const Icon(Icons.add, size: 18),
            label: Text(context.l10n.profilesAdd),
            onPressed: () => addProfile(context, ref),
          ),
        ],
      ),
    );
  }
}

/// Pide el nombre y agrega un perfil, que se abre enseguida.
Future<void> addProfile(BuildContext context, WidgetRef ref) async {
  final controller = ref.read(profilesControllerProvider.notifier);
  await showDialog<void>(
    context: context,
    builder: (_) => ProfileNameDialog(
      title: context.l10n.profilesAddTitle,
      body: context.l10n.profilesAddBody,
      confirm: context.l10n.commonAdd,
      onSubmit: notMainName(context, ref, controller.add, forMain: false),
    ),
  );
}

/// El principal sin nombre propio se muestra como "Principal" (en el
/// idioma de la app): otro perfil no puede llamarse igual, o la lista
/// tendría dos iguales. El dominio no conoce ese nombre traducido.
///
/// [forMain]: el nombre es el del propio principal (cambiarle el nombre).
Future<void> Function(String name) notMainName(
  BuildContext context,
  WidgetRef ref,
  Future<void> Function(String name) submit, {
  required bool forMain,
}) {
  final mainName = context.l10n.profilesMainName.toLowerCase();
  return (name) async {
    final registry = ref.read(profilesControllerProvider).value;
    if (!forMain &&
        registry != null &&
        registry.main.name.isEmpty &&
        name.trim().toLowerCase() == mainName) {
      throw const AppProblem(AppProblemCode.profileNameTaken);
    }
    await submit(name);
  };
}

/// Diálogo con el nombre de un perfil. Muestra el error de validación
/// (vacío, largo, repetido) sin cerrarse.
class ProfileNameDialog extends StatefulWidget {
  final String title;
  final String? body;
  final String confirm;
  final String initialName;
  final Future<void> Function(String name) onSubmit;

  const ProfileNameDialog({
    super.key,
    required this.title,
    this.body,
    required this.confirm,
    this.initialName = '',
    required this.onSubmit,
  });

  @override
  State<ProfileNameDialog> createState() => _ProfileNameDialogState();
}

class _ProfileNameDialogState extends State<ProfileNameDialog> {
  late final _name = TextEditingController(text: widget.initialName);
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final navigator = Navigator.of(context);
    try {
      await widget.onSubmit(_name.text);
      // Agregar un perfil cambia de contenedor y desmonta toda la app, este
      // diálogo incluido: entonces ya no hay nada que cerrar.
      if (mounted) navigator.pop();
    } on AppProblem catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = localizeError(context.l10n, e);
      });
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.title),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.body case final body?) ...[
          Text(body),
          const SizedBox(height: 16),
        ],
        TextField(
          controller: _name,
          autofocus: true,
          maxLength: maxProfileNameLength,
          textCapitalization: TextCapitalization.words,
          decoration: InputDecoration(
            labelText: context.l10n.profilesNameLabel,
            errorText: _error,
          ),
          onSubmitted: (_) => _submit(),
        ),
      ],
    ),
    actions: [
      TextButton(
        onPressed: _busy ? null : () => Navigator.of(context).pop(),
        child: Text(context.l10n.commonCancel),
      ),
      FilledButton(
        onPressed: _busy ? null : _submit,
        child: Text(widget.confirm),
      ),
    ],
  );
}
