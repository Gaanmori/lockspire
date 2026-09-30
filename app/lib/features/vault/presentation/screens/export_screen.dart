// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Gabriel Ángel Montoya Rico

import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../design/lockspire_spacing.dart';
import '../../application/vault_transfer_use_cases.dart';
import '../../domain/entities/vault_entry.dart';
import '../../domain/ports/vault_exporter.dart';
import '../auto_lock_controller.dart';
import '../providers/file_transfer_port_provider.dart';
import '../providers/crypto_port_provider.dart';
import '../providers/vault_import_source_provider.dart';
import '../providers/vault_storage_port_provider.dart';
import '../vault_session_controller.dart';
import '../vault_session_state.dart';
import 'package:lockspire/l10n/l10n.dart';
import 'package:lockspire/l10n/localized_error.dart';
import 'package:lockspire/l10n/localized_values.dart';

/// Exportar la bóveda (ADR 0027): respaldo cifrado de Lockspire o un
/// formato abierto sin cifrar para otro gestor. Siempre pide la
/// contraseña maestra; el archivo se escribe solo donde el usuario elige.
class ExportScreen extends ConsumerStatefulWidget {
  const ExportScreen({super.key});

  @override
  ConsumerState<ExportScreen> createState() => _ExportScreenState();
}

class _ExportScreenState extends ConsumerState<ExportScreen> {
  final _passwordController = TextEditingController();
  bool _obscure = true;

  /// `null` = respaldo cifrado.
  VaultExporter? _exporter;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  bool get _encrypted => _exporter == null;

  Future<bool> _confirmUnencrypted(VaultExporter exporter) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: Icon(
          Icons.warning_amber_rounded,
          color: Theme.of(context).colorScheme.error,
        ),
        title: Text(context.l10n.exportUnencryptedTitle),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Text(
            exporter.passwordsOnly
                ? context.l10n.exportUnencryptedBodyPasswords(
                    context.l10n.exportFormatLabel(exporter.format),
                  )
                : context.l10n.exportUnencryptedBodyAll(
                    context.l10n.exportFormatLabel(exporter.format),
                  ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(context.l10n.commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(context.l10n.exportUnencryptedConfirm),
          ),
        ],
      ),
    );
    return confirmed ?? false;
  }

  Future<void> _export() async {
    final session = ref.read(vaultSessionControllerProvider).value;
    if (session is! VaultSessionUnlocked) return;
    final exporter = _exporter;
    if (exporter != null && !await _confirmUnencrypted(exporter)) return;

    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final crypto = await ref.read(cryptoPortProvider.future);
      final ok = await VerifyMasterPasswordUseCase(crypto: crypto).call(
        password: _passwordController.text,
        header: session.header,
        sessionKey: session.key,
      );
      if (!ok) {
        setState(() {
          _busy = false;
          _error = context.l10n.exportWrongPassword;
        });
        return;
      }

      final Uint8List bytes;
      final String extension;
      final String mimeType;
      if (exporter == null) {
        bytes = await encryptedBackupBytes(
          await ref.read(vaultStoragePortProvider.future),
        );
        extension = 'lockspire';
        mimeType = 'application/octet-stream';
      } else {
        final live = session.vault.entries.where((e) => !e.deleted).toList();
        bytes = Uint8List.fromList(utf8.encode(exporter.encode(live)));
        extension = exporter.fileExtension;
        mimeType = exporter.mimeType;
      }

      final today = DateTime.now().toIso8601String().substring(0, 10);
      if (!mounted) return;
      final files = ref.read(fileTransferPortProvider);
      final dialogTitle = context.l10n.exportSaveDialogTitle;
      final saved = await ref
          .read(autoLockControllerProvider)
          .whileInSystemUi(
            () => files.saveFile(
              dialogTitle: dialogTitle,
              fileName: 'lockspire-$today.$extension',
              bytes: bytes,
              mimeType: mimeType,
              extension: extension,
            ),
          );
      _passwordController.clear();
      if (!mounted) return;
      setState(() => _busy = false);
      if (!saved) return;
      await _showDone(session.vault.entries.where((e) => !e.deleted));
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = context.l10n.exportFailed(localizeError(context.l10n, e));
      });
    }
  }

  Future<void> _showDone(Iterable<VaultEntry> live) {
    final exporter = _exporter;
    final skipped = exporter != null && exporter.passwordsOnly
        ? live.where((e) => e.type != VaultEntryType.password).length
        : 0;
    return showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.exportDoneTitle),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Text(
            exporter == null
                ? context.l10n.exportDoneBackup
                : [
                    context.l10n.exportDoneFile(
                      context.l10n.exportFormatLabel(exporter.format),
                    ),
                    if (skipped > 0) context.l10n.exportSkipped(skipped),
                    context.l10n.exportDeleteReminder,
                  ].join(' '),
          ),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(context.l10n.commonGotIt),
          ),
        ],
      ),
    );
  }

  Widget _option({
    required VaultExporter? value,
    required String title,
    required String subtitle,
    required IconData icon,
  }) {
    final selected = _exporter == value;
    return Card(
      margin: const EdgeInsets.only(bottom: LockspireSpacing.sm),
      child: ListTile(
        leading: Icon(icon),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: Icon(
          selected ? Icons.radio_button_checked : Icons.radio_button_off,
          color: selected ? Theme.of(context).colorScheme.primary : null,
        ),
        onTap: _busy ? null : () => setState(() => _exporter = value),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final exporters = ref.watch(vaultExportersProvider);
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.exportTitle)),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: ListView(
            padding: const EdgeInsets.all(LockspireSpacing.lg),
            children: [
              Text(
                context.l10n.exportFormat,
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: LockspireSpacing.sm),
              _option(
                value: null,
                title: context.l10n.exportBackupLabel,
                subtitle: context.l10n.exportBackupHint,
                icon: Icons.lock_outline,
              ),
              for (final exporter in exporters)
                _option(
                  value: exporter,
                  title: context.l10n.exportFormatLabel(exporter.format),
                  subtitle: context.l10n.exportFormatDescription(
                    exporter.format,
                  ),
                  icon: Icons.description_outlined,
                ),
              const SizedBox(height: LockspireSpacing.md),
              if (!_encrypted)
                Padding(
                  padding: const EdgeInsets.only(bottom: LockspireSpacing.md),
                  child: Text(
                    context.l10n.exportUnencryptedNote,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              TextField(
                controller: _passwordController,
                obscureText: _obscure,
                enabled: !_busy,
                decoration: InputDecoration(
                  labelText: context.l10n.commonMasterPassword,
                  helperText: context.l10n.exportPasswordAlwaysAsked,
                  errorText: _error,
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscure ? Icons.visibility : Icons.visibility_off,
                    ),
                    onPressed: () => setState(() => _obscure = !_obscure),
                  ),
                ),
                onSubmitted: (_) => _busy ? null : _export(),
              ),
              const SizedBox(height: LockspireSpacing.lg),
              FilledButton(
                onPressed: _busy ? null : _export,
                child: _busy
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(context.l10n.exportTitle),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
