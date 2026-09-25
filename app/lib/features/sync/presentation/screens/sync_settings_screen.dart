// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Lockspire

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lockspire/design/lockspire_spacing.dart';

import '../../application/sync_vault_use_case.dart';
import '../../domain/ports/active_sync_provider_port.dart';
import '../../domain/ports/google_drive_account_port.dart';
import '../../domain/ports/one_drive_account_port.dart';
import '../../domain/ports/sync_credentials_port.dart';
import '../../domain/webdav_url_policy.dart';
import '../providers/current_active_sync_provider_provider.dart';
import '../providers/current_google_drive_account_provider.dart';
import '../providers/current_one_drive_account_provider.dart';
import '../providers/current_sync_credentials_provider.dart';
import '../sync_controller.dart';

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

    // Si se deja la contraseña vacía al editar credenciales existentes,
    // se conserva la actual en vez de sobrescribirla con un valor vacío.
    final existing = ref.read(currentSyncCredentialsProvider).value;
    final password = (_passwordController.text.isEmpty && existing != null)
        ? existing.password
        : _passwordController.text;

    await ref
        .read(syncControllerProvider.notifier)
        .saveCredentials(
          WebDavCredentials(
            serverUrl: _serverController.text,
            username: _usernameController.text,
            password: password,
          ),
        );
    _passwordController.clear();
  }

  Future<void> _connectGoogleDrive() async {
    await ref.read(syncControllerProvider.notifier).connectGoogleDrive();
  }

  Future<void> _disconnectGoogleDrive() async {
    await ref.read(syncControllerProvider.notifier).disconnectGoogleDrive();
  }

  Future<void> _connectOneDrive() async {
    await ref.read(syncControllerProvider.notifier).connectOneDrive();
  }

  Future<void> _disconnectOneDrive() async {
    await ref.read(syncControllerProvider.notifier).disconnectOneDrive();
  }

  Future<void> _syncNow() async {
    await ref.read(syncControllerProvider.notifier).syncNow();
  }

  String _describeResult(SyncResult result) => switch (result) {
    SyncUploaded() => 'Se subió la bóveda al servidor.',
    SyncDownloaded() => 'Se bajó la bóveda del servidor.',
    SyncUpToDate() => 'Ya estaba al día — nada que hacer.',
    SyncMerged(:final autoResolvedCount, :final fieldConflictsResolved) =>
      fieldConflictsResolved > 0
          ? 'Se fusionaron los cambios — $fieldConflictsResolved campos se '
                'resolvieron automáticamente (podés ver el valor anterior '
                'en el historial de esa entrada).'
          : autoResolvedCount > 0
          ? 'Se fusionaron los cambios: $autoResolvedCount entradas '
                'resueltas automáticamente.'
          : 'Se fusionaron los cambios.',
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
                return 'Ingresá la URL del servidor';
              }
              return switch (checkWebDavUrl(value)) {
                null => null,
                WebDavUrlProblem.insecure =>
                  'Usá https://: con http:// tu usuario y contraseña del '
                      'servidor viajarían sin cifrar.',
                WebDavUrlProblem.invalid =>
                  'Ingresá una URL completa, p. ej. https://servidor/dav',
              };
            },
          ),
          const SizedBox(height: LockspireSpacing.md),
          TextFormField(
            controller: _usernameController,
            decoration: const InputDecoration(labelText: 'Usuario'),
            validator: (value) =>
                (value == null || value.isEmpty) ? 'Ingresá el usuario' : null,
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
                return 'Ingresá la contraseña';
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

  Widget _buildGoogleDriveSection(
    AsyncValue<GoogleDriveAccount?> accountAsync,
  ) {
    return accountAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) =>
          Text('Ocurrió un error: $error', textAlign: TextAlign.center),
      data: (account) {
        if (account == null) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Sin cuenta conectada. Lockspire solo accede a su propia '
                'carpeta oculta de datos en tu Drive — no ve el resto de '
                'tus archivos.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: LockspireSpacing.lg),
              FilledButton(
                onPressed: _connectGoogleDrive,
                child: const Text('Conectar con Google'),
              ),
            ],
          );
        }
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Conectado como ${account.email}',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: LockspireSpacing.lg),
            OutlinedButton(
              onPressed: _disconnectGoogleDrive,
              child: const Text('Desconectar'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildOneDriveSection(AsyncValue<OneDriveAccount?> accountAsync) {
    return accountAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) =>
          Text('Ocurrió un error: $error', textAlign: TextAlign.center),
      data: (account) {
        if (account == null) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Sin cuenta conectada. Lockspire solo accede a su propia '
                'carpeta especial de app en tu OneDrive — no ve el resto de '
                'tus archivos.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: LockspireSpacing.lg),
              FilledButton(
                onPressed: _connectOneDrive,
                child: const Text('Conectar con OneDrive'),
              ),
            ],
          );
        }
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Conectado como ${account.email}',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: LockspireSpacing.lg),
            OutlinedButton(
              onPressed: _disconnectOneDrive,
              child: const Text('Desconectar'),
            ),
          ],
        );
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
                  _buildGoogleDriveSection(googleAccountAsync)
                else if (_selectedProvider == SyncProviderId.oneDrive)
                  _buildOneDriveSection(oneDriveAccountAsync)
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
                if (syncState.hasError)
                  Text(
                    'No se pudo sincronizar: ${syncState.error}',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                    textAlign: TextAlign.center,
                  )
                else if (syncState.value != null)
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
