// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Lockspire

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../design/lockspire_spacing.dart';
import '../../domain/ports/native_messaging_registration_port.dart';
import '../providers/browser_bridge_provider.dart';
import '../providers/native_messaging_registration_port_provider.dart';

/// Conectar Lockspire con la extensión de Chrome/Edge (ADR 0013). El
/// registro del native host en el navegador es opt-in: solo ocurre al
/// pulsar "Conectar".
class BrowserIntegrationScreen extends ConsumerStatefulWidget {
  const BrowserIntegrationScreen({super.key});

  @override
  ConsumerState<BrowserIntegrationScreen> createState() =>
      _BrowserIntegrationScreenState();
}

class _BrowserIntegrationScreenState
    extends ConsumerState<BrowserIntegrationScreen> {
  late Future<NativeMessagingStatus> _statusFuture;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _statusFuture = _load();
  }

  Future<NativeMessagingStatus> _load() =>
      ref.read(nativeMessagingRegistrationPortProvider).status();

  // Cuerpo con llaves: `() => _statusFuture = ...` devolvería el Future y
  // setState lo rechaza.
  void _refresh() => setState(() {
    _statusFuture = _load();
  });

  Future<void> _run(Future<void> Function() action, String doneMessage) async {
    setState(() => _busy = true);
    String message = doneMessage;
    try {
      await action();
    } catch (e) {
      message = e is StateError ? e.message : 'No se pudo completar: $e';
    }
    if (!mounted) return;
    setState(() => _busy = false);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
    _refresh();
  }

  Future<void> _register() => _run(() async {
    final registered = await ref
        .read(nativeMessagingRegistrationPortProvider)
        .register();
    if (registered.isEmpty) {
      throw StateError('No se encontró ningún navegador compatible.');
    }
  }, 'Listo. Reinicie el navegador si ya estaba abierto.');

  Future<void> _unregister() => _run(
    () => ref.read(nativeMessagingRegistrationPortProvider).unregister(),
    'Lockspire ya no está conectado a los navegadores.',
  );

  Future<void> _registerSystemWide() => _run(
    () =>
        ref.read(nativeMessagingRegistrationPortProvider).registerSystemWide(),
    'Listo para todo el equipo. Reinicie el navegador si ya estaba abierto.',
  );

  Future<void> _unregisterSystemWide() => _run(
    () => ref
        .read(nativeMessagingRegistrationPortProvider)
        .unregisterSystemWide(),
    'Se quitó el registro para todo el equipo.',
  );

  @override
  Widget build(BuildContext context) {
    final bridge = ref.watch(browserBridgeProvider).value;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Navegador')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(LockspireSpacing.lg),
          child: FutureBuilder<NativeMessagingStatus>(
            future: _statusFuture,
            builder: (context, snapshot) {
              final status = snapshot.data;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Con la extensión de Lockspire para Chrome o Edge puede '
                    'rellenar usuario y contraseña en los sitios web. La '
                    'extensión le pide las credenciales a esta app; la '
                    'bóveda nunca sale de acá y, si está bloqueada, la '
                    'extensión le pide que la desbloquee primero.',
                  ),
                  const SizedBox(height: LockspireSpacing.lg),
                  _BridgeStatusTile(status: bridge),
                  const SizedBox(height: LockspireSpacing.md),
                  if (status == null)
                    const Center(child: CircularProgressIndicator())
                  else ...[
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(
                        status.isRegistered
                            ? Icons.check_circle_outline
                            : Icons.link_off,
                      ),
                      title: Text(
                        status.isRegistered
                            ? 'Conectado con '
                                  '${status.registeredIn.map((b) => b.displayName).join(', ')}'
                            : 'No conectado con ningún navegador',
                      ),
                      subtitle: status.hostBinaryFound
                          ? null
                          : const Text(
                              'Falta el componente "lockspire-native-host" '
                              'junto a la app. Ver native-host/README.md.',
                            ),
                    ),
                    const SizedBox(height: LockspireSpacing.md),
                    Wrap(
                      spacing: LockspireSpacing.md,
                      runSpacing: LockspireSpacing.sm,
                      children: [
                        FilledButton(
                          onPressed: (_busy || !status.hostBinaryFound)
                              ? null
                              : _register,
                          child: Text(
                            status.isRegistered
                                ? 'Volver a conectar'
                                : 'Conectar con Chrome/Edge',
                          ),
                        ),
                        if (status.isRegistered)
                          OutlinedButton(
                            onPressed: _busy ? null : _unregister,
                            child: const Text('Desconectar'),
                          ),
                      ],
                    ),
                    if (status.systemWideSupported) ...[
                      const SizedBox(height: LockspireSpacing.xl),
                      Text('Para todo el equipo', style: textTheme.titleMedium),
                      const SizedBox(height: LockspireSpacing.sm),
                      const Text(
                        'Si la extensión sigue diciendo que no está '
                        'conectada, su organización puede estar bloqueando '
                        'las conexiones por usuario (política '
                        '"NativeMessagingUserLevelHosts" de Chrome, visible '
                        'en chrome://policy). En ese caso, registre '
                        'Lockspire para todo el equipo: Windows le va a '
                        'pedir permisos de administrador.',
                      ),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(
                          status.isRegisteredSystemWide
                              ? Icons.check_circle_outline
                              : Icons.link_off,
                        ),
                        title: Text(
                          status.isRegisteredSystemWide
                              ? 'Registrado para todo el equipo'
                              : 'No registrado para todo el equipo',
                        ),
                      ),
                      Wrap(
                        spacing: LockspireSpacing.md,
                        runSpacing: LockspireSpacing.sm,
                        children: [
                          OutlinedButton.icon(
                            icon: const Icon(
                              Icons.admin_panel_settings_outlined,
                            ),
                            onPressed: (_busy || !status.hostBinaryFound)
                                ? null
                                : _registerSystemWide,
                            label: Text(
                              status.isRegisteredSystemWide
                                  ? 'Volver a registrar'
                                  : 'Registrar para todo el equipo',
                            ),
                          ),
                          if (status.isRegisteredSystemWide)
                            OutlinedButton(
                              onPressed: _busy ? null : _unregisterSystemWide,
                              child: const Text('Quitar registro'),
                            ),
                        ],
                      ),
                    ],
                  ],
                  const SizedBox(height: LockspireSpacing.xl),
                  Text('Instalar la extensión', style: textTheme.titleMedium),
                  const SizedBox(height: LockspireSpacing.sm),
                  const Text(
                    'Mientras no esté publicada en la Chrome Web Store: '
                    'abra chrome://extensions (o edge://extensions), active '
                    '"Modo de desarrollador", elija "Cargar descomprimida" y '
                    'seleccione la carpeta extension/dist del proyecto.',
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _BridgeStatusTile extends StatelessWidget {
  final BrowserBridgeStatus? status;

  const _BridgeStatusTile({required this.status});

  @override
  Widget build(BuildContext context) {
    final (icon, text) = switch (status) {
      BrowserBridgeStatus.running => (
        Icons.check_circle_outline,
        'Lockspire está escuchando a la extensión.',
      ),
      BrowserBridgeStatus.anotherInstance => (
        Icons.warning_amber_outlined,
        'Otra instancia de Lockspire ya atiende a la extensión.',
      ),
      BrowserBridgeStatus.unavailable => (
        Icons.error_outline,
        'No se pudo abrir el canal con la extensión en este equipo.',
      ),
      BrowserBridgeStatus.unsupported => (
        Icons.info_outline,
        'La extensión de navegador solo funciona en escritorio.',
      ),
      null => (Icons.hourglass_empty, 'Iniciando…'),
    };
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon),
      title: Text(text),
    );
  }
}
