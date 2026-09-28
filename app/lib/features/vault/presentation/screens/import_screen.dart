// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Lockspire

import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lockspire/shared/platform_capabilities.dart';

import '../../../../design/lockspire_colors.dart';
import '../../../../design/lockspire_spacing.dart';
import '../../application/save_vault_use_case.dart';
import '../../application/vault_transfer_use_cases.dart';
import '../../domain/entities/vault_entry.dart';
import '../../domain/vault_import_merge.dart';
import '../providers/crypto_port_provider.dart';
import '../providers/vault_import_source_provider.dart';
import '../vault_entries_controller.dart';
import '../vault_session_controller.dart';
import '../vault_session_state.dart';

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
    int count(VaultEntryType type) =>
        entries.where((e) => e.type == type).length;
    String part(int n, String one, String many) => '$n ${n == 1 ? one : many}';
    final parts = [
      part(count(VaultEntryType.password), 'contraseña', 'contraseñas'),
      if (count(VaultEntryType.card) > 0)
        part(count(VaultEntryType.card), 'tarjeta', 'tarjetas'),
      if (count(VaultEntryType.document) > 0)
        part(count(VaultEntryType.document), 'documento', 'documentos'),
    ];
    return parts.length == 1
        ? parts.single
        : '${parts.sublist(0, parts.length - 1).join(', ')} y ${parts.last}';
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
      final extension = picked.name.split('.').last.toLowerCase();
      // readAsBytes() funciona igual haya un path local o no — no se crea
      // ninguna copia propia del archivo (docs/THREAT_MODEL.md, actor #8).
      final bytes = await picked.readAsBytes();

      final List<VaultEntry> incoming;
      if (extension == 'lockspire') {
        final backup = await _readBackup(bytes);
        if (backup == null) {
          setState(() => _busy = false);
          return;
        }
        incoming = backup;
        _sourceUnencrypted = false;
      } else {
        final source = ref.read(vaultImportSourceProvider(extension));
        if (source == null) {
          throw FormatException(
            'Formato no reconocido: .$extension. Use un XML de SafeInCloud, '
            'un CSV, un JSON de Bitwarden o un respaldo .lockspire.',
          );
        }
        incoming = await source.parse(utf8.decode(bytes));
        _sourceUnencrypted = true;
      }

      final session = ref.read(vaultSessionControllerProvider).value;
      final existing = session is VaultSessionUnlocked
          ? session.vault.entries
          : const <VaultEntry>[];
      setState(() {
        _selection = selectEntriesToImport(
          existing: existing,
          incoming: incoming,
        );
        _busy = false;
      });
    } on IncorrectBackupPasswordException catch (e) {
      setState(() {
        _busy = false;
        _errorMessage = '$e';
      });
    } on FormatException catch (e) {
      setState(() {
        _busy = false;
        _errorMessage = 'No se pudo leer el archivo: ${e.message}';
      });
    } catch (e) {
      setState(() {
        _busy = false;
        _errorMessage = 'No se pudo leer el archivo: $e';
      });
    }
  }

  /// Pide la contraseña del respaldo y lo abre. `null` si se canceló.
  Future<List<VaultEntry>?> _readBackup(Uint8List bytes) async {
    final password = await showDialog<String>(
      context: context,
      builder: (_) => const _BackupPasswordDialog(),
    );
    if (password == null || !mounted) return null;
    final crypto = await ref.read(cryptoPortProvider.future);
    return ReadEncryptedBackupUseCase(
      crypto: crypto,
    ).call(bytes: bytes, password: password);
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
        _errorMessage = '$e Vuelva a intentar importar.';
      });
    } catch (e) {
      setState(() {
        _busy = false;
        _errorMessage = 'No se pudo importar: $e';
      });
    }
  }

  Future<void> _showDoneDialog(int count) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Importación completada'),
        // Sin tope, en escritorio el texto se estira a todo el ancho.
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Text(
            _sourceUnencrypted
                ? 'Se importaron $count entradas. Por su seguridad: el archivo '
                      'que eligió no está cifrado. Bórrelo del lugar donde lo '
                      'guardó (y de la papelera): Lockspire no puede borrarlo '
                      'por usted.'
                : 'Se importaron $count entradas desde el respaldo.',
          ),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Entendido'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final selection = _selection;

    return Scaffold(
      appBar: AppBar(title: const Text('Importar')),
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
            'Elija el archivo que exportó desde su otro gestor, o un respaldo '
            'de Lockspire. Se lee directo en memoria, sin guardar ninguna '
            'copia, y nunca se duplican entradas que ya tiene.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: LockspireSpacing.md),
          for (final (format, detail) in const [
            ('SafeInCloud', 'XML'),
            ('Bitwarden', 'CSV o JSON sin cifrar'),
            ('Chrome, Edge, Firefox, KeePassXC y otros', 'CSV'),
            ('Respaldo de Lockspire', '.lockspire, con su contraseña'),
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
              child: _spinnerOr('Elegir archivo'),
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
              ? 'No hay entradas nuevas'
              : 'Se importarán ${candidates.length} entradas',
          style: Theme.of(context).textTheme.headlineSmall,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: LockspireSpacing.sm),
        Text(
          [
            if (candidates.isNotEmpty) _summary(candidates),
            if (selection.skipped > 0)
              '${selection.skipped} ya estaban en su bóveda y se omiten',
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
            child: _spinnerOr('Importar'),
          ),
          const SizedBox(height: LockspireSpacing.smMd),
        ],
        OutlinedButton(
          onPressed: _busy ? null : () => setState(() => _selection = null),
          child: Text(candidates.isEmpty ? 'Volver' : 'Cancelar'),
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
      title: const Text('Contraseña del respaldo'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Ingrese la contraseña maestra que tenía la bóveda cuando se '
              'hizo este respaldo.',
            ),
            const SizedBox(height: LockspireSpacing.md),
            TextField(
              controller: _controller,
              obscureText: _obscure,
              autofocus: true,
              decoration: InputDecoration(
                labelText: 'Contraseña',
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
          child: const Text('Cancelar'),
        ),
        FilledButton(onPressed: _submit, child: const Text('Abrir')),
      ],
    );
  }
}
