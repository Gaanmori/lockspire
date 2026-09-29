// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Gabriel Ángel Montoya Rico

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../design/lockspire_spacing.dart';
import '../../domain/ports/native_messaging_registration_port.dart';
import '../providers/browser_bridge_provider.dart';
import '../providers/native_messaging_registration_port_provider.dart';
import 'package:lockspire/shared/domain/app_problem.dart';
import 'package:lockspire/l10n/l10n.dart';
import 'package:lockspire/l10n/localized_error.dart';

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
    final l10n = context.l10n;
    String message = doneMessage;
    try {
      await action();
    } catch (e) {
      message = e is AppProblem
          ? localizeError(l10n, e)
          : l10n.commonCouldNotComplete(localizeError(l10n, e));
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
      throw const AppProblem(AppProblemCode.noSupportedBrowser);
    }
  }, context.l10n.browserRegistered);

  Future<void> _unregister() => _run(
    () => ref.read(nativeMessagingRegistrationPortProvider).unregister(),
    context.l10n.browserUnregistered,
  );

  Future<void> _registerSystemWide() => _run(
    () =>
        ref.read(nativeMessagingRegistrationPortProvider).registerSystemWide(),
    context.l10n.browserRegisteredSystemWide,
  );

  Future<void> _unregisterSystemWide() => _run(
    () => ref
        .read(nativeMessagingRegistrationPortProvider)
        .unregisterSystemWide(),
    context.l10n.browserUnregisteredSystemWide,
  );

  @override
  Widget build(BuildContext context) {
    final bridge = ref.watch(browserBridgeProvider).value;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.browserTitle)),
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
                  Text(context.l10n.browserIntro),
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
                            ? context.l10n.browserConnectedWith(
                                status.registeredIn
                                    .map((b) => b.displayName)
                                    .join(', '),
                              )
                            : context.l10n.browserNotConnected,
                      ),
                      subtitle: status.hostBinaryFound
                          ? null
                          : Text(context.l10n.browserHostMissing),
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
                                ? context.l10n.browserReconnect
                                : context.l10n.browserConnect,
                          ),
                        ),
                        if (status.isRegistered)
                          OutlinedButton(
                            onPressed: _busy ? null : _unregister,
                            child: Text(context.l10n.cloudDisconnect),
                          ),
                      ],
                    ),
                    if (status.systemWideSupported) ...[
                      const SizedBox(height: LockspireSpacing.xl),
                      Text(
                        context.l10n.browserSystemWide,
                        style: textTheme.titleMedium,
                      ),
                      const SizedBox(height: LockspireSpacing.sm),
                      Text(context.l10n.browserSystemWideHint),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(
                          status.isRegisteredSystemWide
                              ? Icons.check_circle_outline
                              : Icons.link_off,
                        ),
                        title: Text(
                          status.isRegisteredSystemWide
                              ? context.l10n.browserSystemWideOn
                              : context.l10n.browserSystemWideOff,
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
                                  ? context.l10n.browserReregister
                                  : context.l10n.browserRegisterSystemWide,
                            ),
                          ),
                          if (status.isRegisteredSystemWide)
                            OutlinedButton(
                              onPressed: _busy ? null : _unregisterSystemWide,
                              child: Text(
                                context.l10n.browserRemoveRegistration,
                              ),
                            ),
                        ],
                      ),
                    ],
                  ],
                  const SizedBox(height: LockspireSpacing.xl),
                  Text(
                    context.l10n.browserInstallExtension,
                    style: textTheme.titleMedium,
                  ),
                  const SizedBox(height: LockspireSpacing.sm),
                  Text(context.l10n.browserInstallExtensionHint),
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
        context.l10n.bridgeRunning,
      ),
      BrowserBridgeStatus.anotherInstance => (
        Icons.warning_amber_outlined,
        context.l10n.bridgeAnotherInstance,
      ),
      BrowserBridgeStatus.unavailable => (
        Icons.error_outline,
        context.l10n.bridgeUnavailable,
      ),
      BrowserBridgeStatus.unsupported => (
        Icons.info_outline,
        context.l10n.bridgeUnsupported,
      ),
      null => (Icons.hourglass_empty, context.l10n.commonStarting),
    };
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon),
      title: Text(text),
    );
  }
}
