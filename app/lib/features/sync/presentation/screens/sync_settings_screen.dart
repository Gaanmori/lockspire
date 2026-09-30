// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Gabriel Ángel Montoya Rico

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lockspire/design/lockspire_spacing.dart';

import 'package:lockspire/features/vault/presentation/vault_session_controller.dart';
import 'package:lockspire/features/vault/presentation/vault_session_state.dart';

import '../../application/sync_vault_use_case.dart';
import '../../domain/ports/active_sync_provider_port.dart';
import '../../domain/ports/sync_credentials_port.dart';
import '../providers/current_active_sync_provider_provider.dart';
import '../providers/current_google_drive_account_provider.dart';
import '../providers/current_one_drive_account_provider.dart';
import '../providers/current_sync_credentials_provider.dart';
import '../sync_accounts_controller.dart';
import '../sync_controller.dart';
import '../widgets/cloud_account_section.dart';
import '../widgets/webdav_settings_form.dart';
import 'package:lockspire/l10n/l10n.dart';
import 'package:lockspire/l10n/localized_error.dart';

class SyncSettingsScreen extends ConsumerStatefulWidget {
  const SyncSettingsScreen({super.key});

  @override
  ConsumerState<SyncSettingsScreen> createState() => _SyncSettingsScreenState();
}

class _SyncSettingsScreenState extends ConsumerState<SyncSettingsScreen> {
  // Qué sub-formulario mostrar — se inicializa con el proveedor activo
  // guardado (ver `_prefillSelection`) una sola vez, mismo criterio que
  // `_prefilled` arriba.
  SyncProviderId? _selectedProvider;
  bool _selectionPrefilled = false;

  /// Guarda WebDAV como nube, confirmando antes si hay que mudar la bóveda.
  Future<bool> _saveWebDav(WebDavCredentials credentials) async {
    if (!await _confirmMove(SyncProviderId.webdav)) return false;
    await ref.read(syncAccountsControllerProvider).saveCredentials(credentials);
    return true;
  }

  Future<void> _connectGoogleDrive() => _connect(
    SyncProviderId.googleDrive,
    ref.read(syncAccountsControllerProvider).connectGoogleDrive,
  );

  Future<void> _disconnectGoogleDrive() async {
    await ref.read(syncAccountsControllerProvider).disconnectGoogleDrive();
  }

  Future<void> _connectOneDrive() => _connect(
    SyncProviderId.oneDrive,
    ref.read(syncAccountsControllerProvider).connectOneDrive,
  );

  /// Un fallo al conectar se muestra: antes quedaba como excepción sin
  /// manejar y el botón parecía no hacer nada (p. ej. un build sin la
  /// configuración OAuth, `--dart-define-from-file`).
  Future<void> _connect(
    SyncProviderId provider,
    Future<void> Function() connect,
  ) async {
    if (!await _confirmMove(provider)) return;
    try {
      await connect();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.l10n.syncConnectFailed(
              syncProviderName(provider),
              localizeError(context.l10n, error),
            ),
          ),
        ),
      );
    }
  }

  /// Si la bóveda ya vive en otra nube, conectar [target] la **muda** (ADR
  /// 0023): se pide confirmación explicando qué pasa con los demás
  /// dispositivos.
  Future<bool> _confirmMove(SyncProviderId target) async {
    final session = ref.read(vaultSessionControllerProvider).value;
    if (session is! VaultSessionUnlocked) return true;
    final home = syncHomeOf(session.vault);
    if (home == null || home == target) return true;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.syncMoveTitle(syncProviderName(target))),
        content: Text(
          context.l10n.syncMoveBody(
            syncProviderName(home),
            syncProviderName(target),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(context.l10n.commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(context.l10n.syncMoveConfirm),
          ),
        ],
      ),
    );
    return confirmed ?? false;
  }

  Future<void> _disconnectOneDrive() async {
    await ref.read(syncAccountsControllerProvider).disconnectOneDrive();
  }

  Future<void> _syncNow() async {
    await ref.read(syncControllerProvider.notifier).syncNow();
  }

  bool _isRollback(Object? error) =>
      error is RemoteVaultRejectedException &&
      error.reason == RemoteVaultRejection.rollback;

  /// ADR 0019: solo el usuario sabe si restauró a propósito una copia
  /// vieja en la nube. Si no fue él, puede ser una manipulación y conviene
  /// revisar el acceso a la cuenta antes que nada.
  Future<void> _confirmReplaceRemote() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.syncReplaceRemoteTitle),
        content: Text(context.l10n.syncReplaceRemoteBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(context.l10n.commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(context.l10n.syncReplaceConfirm),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(syncControllerProvider.notifier).replaceRemoteWithLocal();
    }
  }

  String _describeResult(SyncResult result) => switch (result) {
    SyncUploaded() => context.l10n.syncResultUploaded,
    SyncDownloaded() => context.l10n.syncResultDownloaded,
    SyncUpToDate() => context.l10n.syncResultUpToDate,
    SyncMerged(:final autoResolvedCount, :final fieldConflictsResolved) =>
      fieldConflictsResolved > 0
          ? context.l10n.syncResultMergedFields(fieldConflictsResolved)
          : autoResolvedCount > 0
          ? context.l10n.syncResultMergedEntries(autoResolvedCount)
          : context.l10n.syncResultMerged,
    SyncVaultMoved(:final to) => context.l10n.syncResultMoved(
      syncProviderName(to),
    ),
  };

  Widget _buildProviderPicker() {
    return SegmentedButton<SyncProviderId>(
      segments: const [
        ButtonSegment(value: SyncProviderId.webdav, label: Text('WebDAV')),
        ButtonSegment(
          value: SyncProviderId.googleDrive,
          label: Text('Google Drive'),
        ),
        ButtonSegment(value: SyncProviderId.oneDrive, label: Text('OneDrive')),
      ],
      selected: {_selectedProvider ?? SyncProviderId.webdav},
      onSelectionChanged: (selection) {
        setState(() => _selectedProvider = selection.first);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final credentialsAsync = ref.watch(currentSyncCredentialsProvider);
    final googleAccountAsync = ref.watch(currentGoogleDriveAccountProvider);
    final oneDriveAccountAsync = ref.watch(currentOneDriveAccountProvider);
    final activeProviderAsync = ref.watch(currentActiveSyncProviderProvider);
    final syncState = ref.watch(syncControllerProvider);

    if (!_selectionPrefilled && activeProviderAsync.hasValue) {
      _selectedProvider = activeProviderAsync.value;
      _selectionPrefilled = true;
    }

    final hasSomethingConfigured =
        credentialsAsync.value != null ||
        googleAccountAsync.value != null ||
        oneDriveAccountAsync.value != null;

    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.syncTitle)),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(LockspireSpacing.lg),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(child: _buildProviderPicker()),
                const SizedBox(height: LockspireSpacing.lg),
                if (_selectedProvider == SyncProviderId.googleDrive)
                  CloudAccountSection(
                    account: googleAccountAsync.whenData((a) => a?.email),
                    scopeNote: context.l10n.syncGoogleScopeNote,
                    connectLabel: context.l10n.syncConnectGoogle,
                    onConnect: _connectGoogleDrive,
                    onDisconnect: _disconnectGoogleDrive,
                  )
                else if (_selectedProvider == SyncProviderId.oneDrive)
                  CloudAccountSection(
                    account: oneDriveAccountAsync.whenData((a) => a?.email),
                    scopeNote: context.l10n.syncOneDriveScopeNote,
                    connectLabel: context.l10n.syncConnectOneDrive,
                    onConnect: _connectOneDrive,
                    onDisconnect: _disconnectOneDrive,
                  )
                else
                  credentialsAsync.when(
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (error, _) => Text(
                      context.l10n.commonErrorDetail(
                        localizeError(context.l10n, error),
                      ),
                      textAlign: TextAlign.center,
                    ),
                    data: (saved) =>
                        WebDavSettingsForm(saved: saved, onSave: _saveWebDav),
                  ),
                const SizedBox(height: LockspireSpacing.md),
                // Acción principal de la pantalla una vez conectada la nube.
                FilledButton.tonal(
                  onPressed: !hasSomethingConfigured || syncState.isLoading
                      ? null
                      : _syncNow,
                  child: syncState.isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(context.l10n.syncNow),
                ),
                const SizedBox(height: LockspireSpacing.md),
                if (syncState.hasError) ...[
                  Text(
                    context.l10n.syncFailed(
                      localizeError(context.l10n, syncState.error!),
                    ),
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  if (_isRollback(syncState.error)) ...[
                    const SizedBox(height: LockspireSpacing.md),
                    OutlinedButton(
                      onPressed: _confirmReplaceRemote,
                      child: Text(context.l10n.syncUploadLocal),
                    ),
                  ],
                ] else if (syncState.value != null)
                  Text(
                    _describeResult(syncState.value!),
                    textAlign: TextAlign.center,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
