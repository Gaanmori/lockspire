// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Lockspire

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:lockspire/design/lockspire_spacing.dart';
import 'package:lockspire/features/vault/domain/ports/vault_storage_port.dart';
import 'package:lockspire/features/vault/presentation/providers/vault_auth_attempt_provider.dart';
import 'package:lockspire/features/vault/presentation/widgets/auth_card.dart';

import '../providers/active_sync_port_provider.dart';
import '../providers/is_sync_configured_provider.dart';
import '../restore_vault_controller.dart';
import 'sync_settings_screen.dart';

enum _RestoreStep {
  configureProvider,
  searchingRemote,
  noRemoteVault,
  enterPassword,
}

/// Alternativa a "Crear bóveda" para un dispositivo sin bóveda local que
/// ya tiene una bóveda real sincronizada en otro lado (ver
/// docs/STATE.md — Fase 9, y el problema documentado en README.md).
///
/// Reusa `SyncSettingsScreen` tal cual para el paso de configurar el
/// proveedor — evita duplicar el formulario WebDAV/Google Drive acá. Su
/// botón "Sincronizar ahora" queda habilitado ahí aunque todavía no haya
/// bóveda local (lanza un error explícito si se lo toca antes de
/// restaurar) — no es ideal, pero no rompe nada ni pierde datos;
/// no bloqueante, se puede afinar más adelante.
///
/// **Automático a propósito (verificado en dispositivo real, Fase 9):**
/// apenas `isSyncConfiguredProvider` pasa a `true` (se guardaron
/// credenciales WebDAV o se conectó Google Drive) esta pantalla se cierra
/// sola de vuelta desde `SyncSettingsScreen` y dispara la búsqueda —
/// ningún usuario debería tener que acordarse de volver atrás y tocar
/// "Buscar mi bóveda" a mano. El botón queda igual, como respaldo (ej. si
/// el proveedor ya estaba configurado de antes al entrar a esta pantalla,
/// caso en el que no hay una transición `false → true` que disparar).
class RestoreVaultScreen extends ConsumerStatefulWidget {
  const RestoreVaultScreen({super.key});

  @override
  ConsumerState<RestoreVaultScreen> createState() => _RestoreVaultScreenState();
}

class _RestoreVaultScreenState extends ConsumerState<RestoreVaultScreen> {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  bool _obscure = true;

  _RestoreStep _step = _RestoreStep.configureProvider;
  String? _searchError;
  VaultFile? _downloadedFile;

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _openSyncSettings() async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const SyncSettingsScreen()));
  }

  Future<void> _searchRemoteVault() async {
    setState(() {
      _step = _RestoreStep.searchingRemote;
      _searchError = null;
    });
    try {
      // Token fresco, como `freshActiveSyncPort` (aquí hay un WidgetRef).
      ref
        ..invalidate(syncPortForProvider)
        ..invalidate(activeSyncPortProvider);
      final syncPort = await ref.read(activeSyncPortProvider.future);
      if (syncPort == null) {
        setState(() {
          _step = _RestoreStep.configureProvider;
          _searchError = 'Configure un proveedor de sync primero.';
        });
        return;
      }

      final exists = await syncPort.remoteVaultExists();
      if (!exists) {
        setState(() => _step = _RestoreStep.noRemoteVault);
        return;
      }

      final file = await syncPort.downloadVault();
      if (!mounted) return;
      setState(() {
        _downloadedFile = file;
        _step = _RestoreStep.enterPassword;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _step = _RestoreStep.configureProvider;
        _searchError = 'No se pudo buscar la bóveda remota: $error';
      });
    }
  }

  Future<void> _submitPassword() async {
    if (!_formKey.currentState!.validate()) return;
    await ref
        .read(restoreVaultControllerProvider)
        .restore(
          file: _downloadedFile!,
          masterPassword: _passwordController.text,
        );

    // Éxito: el estado de sesión ya es VaultSessionUnlocked (VaultGateScreen
    // lo re-renderiza solo) — cerramos esta pantalla para que se vea. Si
    // falló (contraseña incorrecta), el error queda en
    // vaultAuthAttemptProvider y esta pantalla sigue montada.
    if (mounted && !ref.read(vaultAuthAttemptProvider).hasError) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    // Se dispara aunque `SyncSettingsScreen` esté encima en el Navigator —
    // este widget sigue montado debajo, Riverpod no necesita que esté en
    // primer plano para notificar. Ver el comentario de la clase.
    ref.listen<AsyncValue<bool>>(isSyncConfiguredProvider, (previous, next) {
      final justConfigured = next.value == true && previous?.value != true;
      if (!justConfigured || _step != _RestoreStep.configureProvider) return;
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
      _searchRemoteVault();
    });

    return Scaffold(
      appBar: AppBar(title: const Text('Restaurar bóveda existente')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(LockspireSpacing.lg),
            child: switch (_step) {
              _RestoreStep.configureProvider => _buildConfigureProviderStep(),
              _RestoreStep.searchingRemote => _buildSearchingStep(),
              _RestoreStep.noRemoteVault => _buildNoRemoteVaultStep(),
              _RestoreStep.enterPassword => _buildPasswordStep(),
            },
          ),
        ),
      ),
    );
  }

  Widget _buildConfigureProviderStep() {
    final configuredAsync = ref.watch(isSyncConfiguredProvider);
    return AuthCard(
      icon: Icons.cloud_sync_outlined,
      title: 'Restaurar bóveda existente',
      subtitle:
          'Conecte el mismo proveedor de sync que ya usa en su otro '
          'dispositivo: vamos a bajar su bóveda desde ahí.',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          OutlinedButton(
            onPressed: _openSyncSettings,
            child: const Text('Configurar proveedor de sync'),
          ),
          const SizedBox(height: LockspireSpacing.md),
          if (_searchError != null)
            Padding(
              padding: const EdgeInsets.only(bottom: LockspireSpacing.md),
              child: Text(
                _searchError!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
                textAlign: TextAlign.center,
              ),
            ),
          configuredAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) =>
                Text('Ocurrió un error: $error', textAlign: TextAlign.center),
            data: (configured) => FilledButton(
              onPressed: configured ? _searchRemoteVault : null,
              child: const Text('Buscar mi bóveda'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchingStep() {
    return const AuthCard(
      icon: Icons.cloud_sync_outlined,
      title: 'Buscando su bóveda…',
      subtitle: 'Revisando el proveedor de sync configurado.',
      child: Center(child: CircularProgressIndicator()),
    );
  }

  Widget _buildNoRemoteVaultStep() {
    return AuthCard(
      icon: Icons.cloud_off_outlined,
      title: 'No hay ninguna bóveda ahí todavía',
      subtitle:
          'El proveedor está conectado, pero no encontramos ninguna '
          'bóveda subida. Si el otro dispositivo todavía no sincronizó, '
          'pruebe desde ahí primero.',
      child: SizedBox(
        width: double.infinity,
        child: OutlinedButton(
          onPressed: () =>
              setState(() => _step = _RestoreStep.configureProvider),
          child: const Text('Volver'),
        ),
      ),
    );
  }

  Widget _buildPasswordStep() {
    final attempt = ref.watch(vaultAuthAttemptProvider);
    final isLoading = attempt.isLoading;

    return Form(
      key: _formKey,
      child: AuthCard(
        icon: Icons.lock_outline,
        title: 'Encontramos su bóveda',
        subtitle: 'Ingrese su contraseña maestra para desbloquearla.',
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _passwordController,
              obscureText: _obscure,
              autofocus: true,
              enabled: !isLoading,
              decoration: InputDecoration(
                labelText: 'Contraseña maestra',
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscure ? Icons.visibility : Icons.visibility_off,
                  ),
                  onPressed: () => setState(() => _obscure = !_obscure),
                ),
              ),
              validator: (value) => (value == null || value.isEmpty)
                  ? 'Ingrese su contraseña maestra'
                  : null,
              onFieldSubmitted: (_) => isLoading ? null : _submitPassword(),
            ),
            const SizedBox(height: LockspireSpacing.lg),
            if (isLoading)
              const Padding(
                padding: EdgeInsets.only(bottom: LockspireSpacing.md),
                child: ClipRRect(
                  borderRadius: BorderRadius.all(Radius.circular(4)),
                  child: LinearProgressIndicator(),
                ),
              )
            else if (attempt.hasError)
              Padding(
                padding: const EdgeInsets.only(bottom: LockspireSpacing.md),
                child: Text(
                  'Contraseña incorrecta',
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                  textAlign: TextAlign.center,
                ),
              ),
            if (!isLoading)
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _submitPassword,
                  child: const Text('Restaurar bóveda'),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
