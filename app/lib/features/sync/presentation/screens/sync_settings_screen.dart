// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Lockspire

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lockspire/design/lockspire_spacing.dart';

import 'package:lockspire/features/vault/presentation/vault_session_controller.dart';
import 'package:lockspire/features/vault/presentation/vault_session_state.dart';

import '../../application/sync_vault_use_case.dart';
import '../../domain/ports/active_sync_provider_port.dart';
import '../../domain/ports/sync_credentials_port.dart';
import '../../domain/webdav_url_policy.dart';
import '../providers/current_active_sync_provider_provider.dart';
import '../providers/current_google_drive_account_provider.dart';
import '../providers/current_one_drive_account_provider.dart';
import '../providers/current_sync_credentials_provider.dart';
import '../sync_accounts_controller.dart';
import '../sync_controller.dart';
import '../widgets/cloud_account_section.dart';

class SyncSettingsScreen extends ConsumerStatefulWidget {
  const SyncSettingsScreen({super.key});

  @override
  ConsumerState<SyncSettingsScreen> createState() => _SyncSettingsScreenState();
}

class _SyncSettingsScreenState extends ConsumerState<SyncSettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _serverController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();

  // Los campos se precargan con las credenciales guardadas una sola vez.
  // build() se vuelve a ejecutar cada vez que cambia syncControllerProvider
  // (ej. al presionar "Sincronizar ahora") — sin este flag, ese rebuild
  // pisaría cualquier edición sin guardar en curso (ej. el usuario cambia
  // la URL del servidor y, antes de tocar "Guardar", presiona "Sincronizar
  // ahora" para probar la conexión actual primero).
  bool _prefilled = false;

  // Qué sub-formulario mostrar — se inicializa con el proveedor activo
  // guardado (ver `_prefillSelection`) una sola vez, mismo criterio que
  // `_prefilled` arriba.
  SyncProviderId? _selectedProvider;
  bool _selectionPrefilled = false;

  @override
  void dispose() {
    _serverController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (!await _confirmMove(SyncProviderId.webdav)) return;

    // Si se deja la contraseña vacía al editar credenciales existentes,
    // se conserva la actual en vez de sobrescribirla con un valor vacío.
    final existing = ref.read(currentSyncCredentialsProvider).value;
    final password = (_passwordController.text.isEmpty && existing != null)
        ? existing.password
        : _passwordController.text;

    await ref
        .read(syncAccountsControllerProvider)
        .saveCredentials(
          WebDavCredentials(
            serverUrl: _serverController.text,
            username: _usernameController.text,
            password: password,
          ),
        );
    _passwordController.clear();
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
            'No se pudo conectar con ${syncProviderName(provider)}: $error',
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
        title: Text('¿Mudar la bóveda a ${syncProviderName(target)}?'),
        content: Text(
          'Su bóveda se sincroniza con ${syncProviderName(home)}. Si continúa, '
          'pasa a sincronizarse con ${syncProviderName(target)} y se deja un '
          'aviso en ${syncProviderName(home)}.\n\n'
          'Sus otros dispositivos van a recibir ese aviso la próxima vez que '
          'sincronicen, y tendrán que conectar ${syncProviderName(target)} '
          'para seguir. No se pierde nada: lo que esté en '
          '${syncProviderName(target)} se fusiona con esta bóveda.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Mudar'),
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
        title: const Text('¿Reemplazar la copia de la nube?'),
        content: const Text(
          'La nube tiene una versión más vieja que la de este dispositivo. '
          'Si restauró una copia antigua a propósito, puede reemplazarla '
          'con la de este dispositivo: no pierde nada que tenga aquí.\n\n'
          'Si no fue usted, alguien pudo haber accedido a su cuenta de la '
          'nube: cambie esa contraseña antes de seguir.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Reemplazar'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(syncControllerProvider.notifier).replaceRemoteWithLocal();
    }
  }

  String _describeResult(SyncResult result) => switch (result) {
    SyncUploaded() => 'Se subió la bóveda al servidor.',
    SyncDownloaded() => 'Se bajó la bóveda del servidor.',
    SyncUpToDate() => 'Ya estaba al día — nada que hacer.',
    SyncMerged(:final autoResolvedCount, :final fieldConflictsResolved) =>
      fieldConflictsResolved > 0
          ? 'Se fusionaron los cambios — $fieldConflictsResolved campos se '
                'resolvieron automáticamente (puede ver el valor anterior '
                'en el historial de esa entrada).'
          : autoResolvedCount > 0
          ? 'Se fusionaron los cambios: $autoResolvedCount entradas '
                'resueltas automáticamente.'
          : 'Se fusionaron los cambios.',
    SyncVaultMoved(:final to) =>
      'Su bóveda se mudó a ${syncProviderName(to)}. Conéctela arriba para '
          'seguir sincronizando.',
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

  Widget _buildWebDavForm(WebDavCredentials? credentials) {
    if (!_prefilled && credentials != null) {
      _serverController.text = credentials.serverUrl;
      _usernameController.text = credentials.username;
      _prefilled = true;
    }
    return Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextFormField(
            controller: _serverController,
            decoration: const InputDecoration(
              labelText: 'URL del servidor WebDAV',
              hintText: 'https://mi-servidor.ejemplo/dav',
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Ingrese la URL del servidor';
              }
              return switch (checkWebDavUrl(value)) {
                null => null,
                WebDavUrlProblem.insecure =>
                  'Use https://: con http:// su usuario y contraseña del '
                      'servidor viajarían sin cifrar.',
                WebDavUrlProblem.invalid =>
                  'Ingrese una URL completa, p. ej. https://servidor/dav',
              };
            },
          ),
          const SizedBox(height: LockspireSpacing.md),
          TextFormField(
            controller: _usernameController,
            decoration: const InputDecoration(labelText: 'Usuario'),
            validator: (value) =>
                (value == null || value.isEmpty) ? 'Ingrese el usuario' : null,
          ),
          const SizedBox(height: LockspireSpacing.md),
          TextFormField(
            controller: _passwordController,
            obscureText: true,
            decoration: InputDecoration(
              labelText: 'Contraseña',
              hintText: credentials != null
                  ? '(sin cambios si se deja vacío)'
                  : null,
            ),
            validator: (value) {
              if (credentials == null && (value == null || value.isEmpty)) {
                return 'Ingrese la contraseña';
              }
              return null;
            },
          ),
          const SizedBox(height: LockspireSpacing.lg),
          FilledButton(onPressed: _save, child: const Text('Guardar')),
        ],
      ),
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
      appBar: AppBar(title: const Text('Sincronización')),
      body: Center(
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
                    scopeNote:
                        'Lockspire solo accede a su propia carpeta '
                        'oculta de datos en su Drive: no ve el resto de '
                        'sus archivos.',
                    connectLabel: 'Conectar con Google',
                    onConnect: _connectGoogleDrive,
                    onDisconnect: _disconnectGoogleDrive,
                  )
                else if (_selectedProvider == SyncProviderId.oneDrive)
                  CloudAccountSection(
                    account: oneDriveAccountAsync.whenData((a) => a?.email),
                    scopeNote:
                        'Lockspire solo accede a su propia carpeta '
                        'especial de app en su OneDrive: no ve el resto '
                        'de sus archivos.',
                    connectLabel: 'Conectar con OneDrive',
                    onConnect: _connectOneDrive,
                    onDisconnect: _disconnectOneDrive,
                  )
                else
                  credentialsAsync.when(
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (error, _) => Text(
                      'Ocurrió un error: $error',
                      textAlign: TextAlign.center,
                    ),
                    data: _buildWebDavForm,
                  ),
                const SizedBox(height: LockspireSpacing.md),
                OutlinedButton(
                  onPressed: !hasSomethingConfigured || syncState.isLoading
                      ? null
                      : _syncNow,
                  child: syncState.isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Sincronizar ahora'),
                ),
                const SizedBox(height: LockspireSpacing.md),
                if (syncState.hasError) ...[
                  Text(
                    'No se pudo sincronizar: ${syncState.error}',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  if (_isRollback(syncState.error)) ...[
                    const SizedBox(height: LockspireSpacing.md),
                    OutlinedButton(
                      onPressed: _confirmReplaceRemote,
                      child: const Text('Subir la versión de este dispositivo'),
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
