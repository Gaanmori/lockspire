// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Gabriel Ángel Montoya Rico

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lockspire/shared/platform_capabilities.dart';

import '../../../../design/lockspire_colors.dart';
import '../../../../design/lockspire_spacing.dart';
import '../../application/save_vault_use_case.dart';
import '../../application/prepare_import_use_case.dart';
import '../../application/vault_transfer_use_cases.dart';
import '../../domain/entities/vault_entry.dart';
import '../../domain/vault_import_merge.dart';
import '../providers/vault_import_source_provider.dart';
import '../vault_entries_controller.dart';
import '../vault_session_controller.dart';
import '../vault_session_state.dart';
import 'package:lockspire/l10n/l10n.dart';
import 'package:lockspire/l10n/localized_error.dart';

/// Importar desde SafeInCloud (XML), un CSV (Bitwarden, Chrome, Firefox,
/// KeePassXC…), el JSON de Bitwarden o un respaldo de Lockspire (ADR 0027).
///
/// El archivo elegido se lee directo a memoria (sin copiarlo a ningún
/// temporal propio de la app) y se descarta la referencia en cuanto
/// termina el parseo — solo las [VaultEntry] candidatas quedan en el
/// estado de esta pantalla hasta que el usuario confirma o cancela. Nunca
/// duplica: ver `selectEntriesToImport`.
class ImportScreen extends ConsumerStatefulWidget {
  const ImportScreen({super.key});

  @override
  ConsumerState<ImportScreen> createState() => _ImportScreenState();
}

class _ImportScreenState extends ConsumerState<ImportScreen> {
  ImportSelection? _selection;

  /// El archivo de origen no estaba cifrado: al terminar se recuerda
  /// borrarlo.
  bool _sourceUnencrypted = true;
  bool _busy = false;
  String? _errorMessage;

  static const _extensions = ['xml', 'csv', 'json', 'lockspire'];

  String _summary(List<VaultEntry> entries) {
    final l10n = context.l10n;
    int count(VaultEntryType type) =>
        entries.where((e) => e.type == type).length;
    final cards = count(VaultEntryType.card);
    final documents = count(VaultEntryType.document);
    final parts = [
      l10n.importCountPasswords(count(VaultEntryType.password)),
      if (cards > 0) l10n.importCountCards(cards),
      if (documents > 0) l10n.importCountDocuments(documents),
    ];
    return parts.length == 1
        ? parts.single
        : l10n.commonListAnd(
            parts.sublist(0, parts.length - 1).join(', '),
            parts.last,
          );
  }

  Future<void> _pickFile() async {
    setState(() {
      _busy = true;
      _errorMessage = null;
      _selection = null;
    });

    try {
      // Android no conoce `.lockspire` y el filtro por extensión puede
      // fallar: ahí se elige cualquier archivo y se valida después.
      final isAndroid = ref.read(platformCapabilitiesProvider).isAndroid;
      final picked = await FilePicker.pickFile(
        type: isAndroid ? FileType.any : FileType.custom,
        allowedExtensions: isAndroid ? null : _extensions,
      );
      if (picked == null) {
        setState(() => _busy = false);
        return;
      }
      // readAsBytes() funciona igual haya un path local o no — no se crea
      // ninguna copia propia del archivo (docs/THREAT_MODEL.md, actor #8).
      final bytes = await picked.readAsBytes();
      final session = ref.read(vaultSessionControllerProvider).value;
      final prepared =
          await (await ref.read(prepareImportUseCaseProvider.future)).call(
            bytes: bytes,
            fileName: picked.name,
            existing: session is VaultSessionUnlocked
                ? session.vault.entries
                : const <VaultEntry>[],
            askBackupPassword: () => showDialog<String>(
              context: context,
              builder: (_) => const _BackupPasswordDialog(),
            ),
          );
      if (!mounted) return;
      setState(() {
        _busy = false;
        if (prepared == null) return;
        _selection = prepared.selection;
        _sourceUnencrypted = prepared.sourceUnencrypted;
      });
    } on UnknownImportFormatException catch (e) {
      setState(() {
        _busy = false;
        _errorMessage = localizeError(context.l10n, e);
      });
    } on IncorrectBackupPasswordException catch (e) {
      setState(() {
        _busy = false;
        _errorMessage = localizeError(context.l10n, e);
      });
    } on FormatException catch (e) {
      setState(() {
        _busy = false;
        _errorMessage = context.l10n.importReadFailed(e.message);
      });
    } catch (e) {
      setState(() {
        _busy = false;
        _errorMessage = context.l10n.importReadFailed(
          localizeError(context.l10n, e),
        );
      });
    }
  }

  Future<void> _confirmImport() async {
    final selection = _selection;
    if (selection == null || selection.toAdd.isEmpty) return;

    setState(() {
      _busy = true;
      _errorMessage = null;
    });

    try {
      await ref
          .read(vaultEntriesControllerProvider)
          .importEntries(selection.toAdd);
      if (!mounted) return;
      setState(() => _selection = null);
      await _showDoneDialog(selection.toAdd.length);
      if (mounted) Navigator.of(context).pop();
    } on VaultWriteConflictException catch (e) {
      setState(() {
        _busy = false;
        _errorMessage = context.l10n.importConflict(
          localizeError(context.l10n, e),
        );
      });
    } catch (e) {
      setState(() {
        _busy = false;
        _errorMessage = context.l10n.importFailed(
          localizeError(context.l10n, e),
        );
      });
    }
  }

  Future<void> _showDoneDialog(int count) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.l10n.importDoneTitle),
        // Sin tope, en escritorio el texto se estira a todo el ancho.
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Text(
            _sourceUnencrypted
                ? context.l10n.importDoneUnencrypted(count)
                : context.l10n.importDoneBackup(count),
          ),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(context.l10n.commonGotIt),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final selection = _selection;

    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.importTitle)),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Padding(
            padding: const EdgeInsets.all(LockspireSpacing.lg),
            child: selection == null
                ? _buildPickerView(context)
                : _buildPreviewView(context, selection),
          ),
        ),
      ),
    );
  }

  Widget _error(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: LockspireSpacing.md),
    child: Text(
      _errorMessage!,
      style: TextStyle(color: Theme.of(context).colorScheme.error),
      textAlign: TextAlign.center,
    ),
  );

  Widget _spinnerOr(String label) => _busy
      ? const SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        )
      : Text(label);

  Widget _buildPickerView(BuildContext context) {
    final bodySmall = Theme.of(context).textTheme.bodySmall;
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.upload_file_outlined,
            size: 48,
            color: context.palette.textPlaceholder,
          ),
          const SizedBox(height: LockspireSpacing.md),
          Text(
            context.l10n.importIntro,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: LockspireSpacing.md),
          for (final (format, detail) in [
            ('SafeInCloud', 'XML'),
            ('Bitwarden', context.l10n.importBitwardenDetail),
            (context.l10n.importOthersSource, 'CSV'),
            (
              context.l10n.importLockspireBackup,
              context.l10n.importLockspireBackupDetail,
            ),
          ])
            Padding(
              padding: const EdgeInsets.only(bottom: LockspireSpacing.xs),
              child: Text('$format — $detail', style: bodySmall),
            ),
          const SizedBox(height: LockspireSpacing.lg),
          if (_errorMessage != null) _error(context),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _busy ? null : _pickFile,
              child: _spinnerOr(context.l10n.importChooseFile),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPreviewView(BuildContext context, ImportSelection selection) {
    final candidates = selection.toAdd;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          candidates.isEmpty
              ? context.l10n.importNothingNew
              : context.l10n.importWillImport(candidates.length),
          style: Theme.of(context).textTheme.headlineSmall,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: LockspireSpacing.sm),
        Text(
          [
            if (candidates.isNotEmpty) _summary(candidates),
            if (selection.skipped > 0)
              context.l10n.importSkipped(selection.skipped),
          ].join('. '),
          style: Theme.of(context).textTheme.bodySmall,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: LockspireSpacing.md),
        ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 300),
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: candidates.length,
            itemBuilder: (context, index) =>
                ListTile(dense: true, title: Text(candidates[index].title)),
          ),
        ),
        const SizedBox(height: LockspireSpacing.lg),
        if (_errorMessage != null) _error(context),
        if (candidates.isNotEmpty) ...[
          FilledButton(
            onPressed: _busy ? null : _confirmImport,
            child: _spinnerOr(context.l10n.importTitle),
          ),
          const SizedBox(height: LockspireSpacing.smMd),
        ],
        OutlinedButton(
          onPressed: _busy ? null : () => setState(() => _selection = null),
          child: Text(
            candidates.isEmpty
                ? context.l10n.commonBack
                : context.l10n.commonCancel,
          ),
        ),
      ],
    );
  }
}

class _BackupPasswordDialog extends StatefulWidget {
  const _BackupPasswordDialog();

  @override
  State<_BackupPasswordDialog> createState() => _BackupPasswordDialogState();
}

class _BackupPasswordDialogState extends State<_BackupPasswordDialog> {
  final _controller = TextEditingController();
  bool _obscure = true;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    if (_controller.text.isEmpty) return;
    Navigator.of(context).pop(_controller.text);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(context.l10n.importBackupPassword),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(context.l10n.importBackupPasswordHint),
            const SizedBox(height: LockspireSpacing.md),
            TextField(
              controller: _controller,
              obscureText: _obscure,
              autofocus: true,
              decoration: InputDecoration(
                labelText: context.l10n.fieldPassword,
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscure ? Icons.visibility : Icons.visibility_off,
                  ),
                  onPressed: () => setState(() => _obscure = !_obscure),
                ),
              ),
              onSubmitted: (_) => _submit(),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(context.l10n.commonCancel),
        ),
        FilledButton(onPressed: _submit, child: Text(context.l10n.commonOpen)),
      ],
    );
  }
}
