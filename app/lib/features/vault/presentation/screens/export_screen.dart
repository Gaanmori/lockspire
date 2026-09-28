// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Lockspire

import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lockspire/shared/platform_capabilities.dart';

import '../../../../design/lockspire_spacing.dart';
import '../../application/vault_transfer_use_cases.dart';
import '../../domain/entities/vault_entry.dart';
import '../../domain/ports/vault_exporter.dart';
import '../providers/crypto_port_provider.dart';
import '../providers/vault_import_source_provider.dart';
import '../providers/vault_storage_port_provider.dart';
import '../vault_session_controller.dart';
import '../vault_session_state.dart';

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
        title: const Text('El archivo no va a estar cifrado'),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Text(
            'Cualquiera que abra el ${exporter.label} verá todas sus '
            'contraseñas${exporter.passwordsOnly ? '' : ', tarjetas y documentos'}. '
            'Guárdelo solo el tiempo necesario para importarlo en el otro '
            'gestor y después bórrelo, también de la papelera. No lo suba '
            'a la nube ni lo envíe por correo o chat.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Entiendo, exportar'),
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
          _error = 'La contraseña maestra no es correcta';
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
      final isAndroid = ref.read(platformCapabilitiesProvider).isAndroid;
      final saved = await FilePicker.saveFile(
        dialogTitle: 'Guardar exportación',
        fileName: 'lockspire-$today.$extension',
        bytes: bytes,
        mimeType: mimeType,
        type: isAndroid ? FileType.any : FileType.custom,
        allowedExtensions: isAndroid ? null : [extension],
      );
      _passwordController.clear();
      if (!mounted) return;
      setState(() => _busy = false);
      if (saved == null) return;
      await _showDone(session.vault.entries.where((e) => !e.deleted));
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = 'No se pudo exportar: $e';
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
        title: const Text('Exportación lista'),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Text(
            exporter == null
                ? 'Se guardó el respaldo cifrado. Para abrirlo hace falta la '
                      'contraseña maestra actual; si la cambia después, este '
                      'respaldo sigue pidiendo la de hoy.'
                : [
                    'Se guardó el ${exporter.label}.',
                    if (skipped > 0)
                      '$skipped tarjetas o documentos no se incluyeron: este '
                          'formato solo lleva contraseñas.',
                    'Recuerde borrarlo, también de la papelera, en cuanto lo '
                        'importe en el otro gestor.',
                  ].join(' '),
          ),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Entendido'),
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
      appBar: AppBar(title: const Text('Exportar')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: ListView(
            padding: const EdgeInsets.all(LockspireSpacing.lg),
            children: [
              Text('Formato', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: LockspireSpacing.sm),
              _option(
                value: null,
                title: 'Respaldo de Lockspire (cifrado)',
                subtitle:
                    'Todo su contenido, cifrado con su contraseña maestra. '
                    'Para guardarlo como respaldo o restaurarlo en otro '
                    'Lockspire.',
                icon: Icons.lock_outline,
              ),
              for (final exporter in exporters)
                _option(
                  value: exporter,
                  title: exporter.label,
                  subtitle: exporter.description,
                  icon: Icons.description_outlined,
                ),
              const SizedBox(height: LockspireSpacing.md),
              if (!_encrypted)
                Padding(
                  padding: const EdgeInsets.only(bottom: LockspireSpacing.md),
                  child: Text(
                    'Este formato no está cifrado. Úselo solo para pasar sus '
                    'datos a otro gestor.',
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
                  labelText: 'Contraseña maestra',
                  helperText: 'Para exportar siempre se pide la contraseña.',
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
                    : const Text('Exportar'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
