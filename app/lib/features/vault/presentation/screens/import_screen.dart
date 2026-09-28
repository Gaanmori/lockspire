// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Lockspire

import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../design/lockspire_colors.dart';
import '../../../../design/lockspire_spacing.dart';
import '../../application/save_vault_use_case.dart';
import '../../domain/entities/vault_entry.dart';
import '../providers/vault_import_source_provider.dart';
import '../vault_entries_controller.dart';

/// Importar contraseñas desde un export XML de SafeInCloud (ver
/// docs/STATE.md — Fase 6, docs/THREAT_MODEL.md actor #8).
///
/// El archivo elegido se lee directo a memoria (sin copiarlo a ningún
/// temporal propio de la app) y se descarta la referencia en cuanto
/// termina el parseo — solo las [VaultEntry] candidatas quedan en el
/// estado de esta pantalla hasta que el usuario confirma o cancela.
class ImportScreen extends ConsumerStatefulWidget {
  const ImportScreen({super.key});

  @override
  ConsumerState<ImportScreen> createState() => _ImportScreenState();
}

class _ImportScreenState extends ConsumerState<ImportScreen> {
  List<VaultEntry>? _candidates;
  bool _busy = false;
  String? _errorMessage;

  /// "12 contraseñas, 3 tarjetas y 1 documento" (ADR 0025).
  String get _summary {
    final candidates = _candidates ?? const [];
    int count(VaultEntryType type) =>
        candidates.where((e) => e.type == type).length;
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
      _candidates = null;
    });

    try {
      final picked = await FilePicker.pickFile(
        type: FileType.custom,
        allowedExtensions: ['xml'],
      );
      if (picked == null) {
        setState(() => _busy = false);
        return;
      }

      // readAsBytes() funciona igual haya un path local o no (web) — no
      // hace falta manejar ambos casos por separado, y no se crea ninguna
      // copia propia del archivo (ver docs/THREAT_MODEL.md, actor #8).
      final content = utf8.decode(await picked.readAsBytes());

      final source = ref.read(vaultImportSourceProvider);
      final entries = await source.parse(content);

      setState(() {
        _candidates = entries;
        _busy = false;
      });
    } catch (e) {
      setState(() {
        _busy = false;
        _errorMessage =
            'No se pudo leer el archivo. ¿Es un export XML de SafeInCloud '
            'válido? ($e)';
      });
    }
  }

  Future<void> _confirmImport() async {
    final candidates = _candidates;
    if (candidates == null) return;

    setState(() {
      _busy = true;
      _errorMessage = null;
    });

    try {
      await ref.read(vaultEntriesControllerProvider).importEntries(candidates);
      if (!mounted) return;
      setState(() => _candidates = null);
      await _showDeleteReminderDialog(candidates.length);
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

  Future<void> _showDeleteReminderDialog(int count) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Importación completada'),
        // Sin tope, en escritorio el texto se estira a todo el ancho.
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Text(
            'Se importaron $count entradas. Por su seguridad: el archivo de '
            'exportación que eligió no está cifrado. Bórrelo del lugar '
            'donde lo guardó: Lockspire no puede borrarlo por usted.',
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
    final candidates = _candidates;

    return Scaffold(
      appBar: AppBar(title: const Text('Importar desde SafeInCloud')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Padding(
            padding: const EdgeInsets.all(LockspireSpacing.lg),
            child: candidates == null
                ? _buildPickerView(context)
                : _buildPreviewView(context, candidates),
          ),
        ),
      ),
    );
  }

  Widget _buildPickerView(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.upload_file_outlined,
          size: 48,
          color: context.palette.textPlaceholder,
        ),
        const SizedBox(height: LockspireSpacing.md),
        Text(
          'Elija el archivo XML exportado desde SafeInCloud. Se lee '
          'directo en memoria, sin guardar ninguna copia.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: LockspireSpacing.lg),
        if (_errorMessage != null)
          Padding(
            padding: const EdgeInsets.only(bottom: LockspireSpacing.md),
            child: Text(
              _errorMessage!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
              textAlign: TextAlign.center,
            ),
          ),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: _busy ? null : _pickFile,
            child: _busy
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Elegir archivo'),
          ),
        ),
      ],
    );
  }

  Widget _buildPreviewView(BuildContext context, List<VaultEntry> candidates) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Se importarán ${candidates.length} entradas',
          style: Theme.of(context).textTheme.headlineSmall,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: LockspireSpacing.sm),
        Text(
          _summary,
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
        if (_errorMessage != null)
          Padding(
            padding: const EdgeInsets.only(bottom: LockspireSpacing.md),
            child: Text(
              _errorMessage!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
              textAlign: TextAlign.center,
            ),
          ),
        FilledButton(
          onPressed: _busy ? null : _confirmImport,
          child: _busy
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Importar'),
        ),
        const SizedBox(height: LockspireSpacing.smMd),
        OutlinedButton(
          onPressed: _busy ? null : () => setState(() => _candidates = null),
          child: const Text('Cancelar'),
        ),
      ],
    );
  }
}
