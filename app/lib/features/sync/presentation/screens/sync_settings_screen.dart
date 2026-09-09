// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Lockspire

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lockspire/design/lockspire_spacing.dart';

import '../../application/sync_vault_use_case.dart';
import '../../domain/ports/sync_credentials_port.dart';
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

  Future<void> _syncNow() async {
    await ref.read(syncControllerProvider.notifier).syncNow();
  }

  String _describeResult(SyncResult result) => switch (result) {
    SyncUploaded() => 'Se subió la bóveda al servidor.',
    SyncDownloaded() => 'Se bajó la bóveda del servidor.',
    SyncUpToDate() => 'Ya estaba al día — nada que hacer.',
    SyncConflict() =>
      'Conflicto: cambiaron los dos lados desde la última sincronización. '
          'La resolución automática todavía no está implementada — '
          'no se sobrescribió nada.',
  };

  @override
  Widget build(BuildContext context) {
    final credentialsAsync = ref.watch(currentSyncCredentialsProvider);
    final syncState = ref.watch(syncControllerProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Sincronización (WebDAV)')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(LockspireSpacing.lg),
            child: credentialsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) =>
                  Text('Ocurrió un error: $error', textAlign: TextAlign.center),
              data: (credentials) {
                if (credentials != null) {
                  _serverController.text = credentials.serverUrl;
                  _usernameController.text = credentials.username;
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
                        validator: (value) => (value == null || value.isEmpty)
                            ? 'Ingresá la URL del servidor'
                            : null,
                      ),
                      const SizedBox(height: LockspireSpacing.md),
                      TextFormField(
                        controller: _usernameController,
                        decoration: const InputDecoration(labelText: 'Usuario'),
                        validator: (value) => (value == null || value.isEmpty)
                            ? 'Ingresá el usuario'
                            : null,
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
                          if (credentials == null &&
                              (value == null || value.isEmpty)) {
                            return 'Ingresá la contraseña';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: LockspireSpacing.lg),
                      FilledButton(
                        onPressed: _save,
                        child: const Text('Guardar'),
                      ),
                      const SizedBox(height: LockspireSpacing.md),
                      OutlinedButton(
                        onPressed: credentials == null || syncState.isLoading
                            ? null
                            : _syncNow,
                        child: syncState.isLoading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
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
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
