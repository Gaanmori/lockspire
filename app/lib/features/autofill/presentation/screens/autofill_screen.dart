// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Gabriel Ángel Montoya Rico

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../design/lockspire_spacing.dart';
import '../../../vault/domain/entities/vault.dart';
import '../../../vault/domain/entities/vault_entry.dart';
import '../../../vault/presentation/vault_entries_controller.dart';
import '../../../browser_bridge/domain/origin_matcher.dart';
import '../../../vault/presentation/providers/auto_lock_timeout_setting_provider.dart';
import '../../domain/autofill_session.dart';
import '../../domain/autofill_web_origin.dart';
import '../widgets/get_credential_view.dart';
import '../widgets/create_credential_view.dart';
import 'package:lockspire/l10n/l10n.dart';

const _channel = MethodChannel('com.lockspire.lockspire/autofill');

/// Pantalla mostrada dentro de `AutofillActivity` (ADR 0011) una vez que
/// la bóveda ya está desbloqueada — la parte nativa (Kotlin) nunca ve
/// nada de esto, solo reenvía el resultado final.
class AutofillScreen extends ConsumerStatefulWidget {
  final Vault vault;

  const AutofillScreen({super.key, required this.vault});

  @override
  ConsumerState<AutofillScreen> createState() => _AutofillScreenState();
}

class _AutofillScreenState extends ConsumerState<AutofillScreen> {
  Future<Map<String, dynamic>>? _requestFuture;

  @override
  void initState() {
    super.initState();
    _requestFuture = _fetchRequest();
    _startNativeSession();
  }

  /// Se desbloqueó para rellenar: durante el tiempo del auto-bloqueo, el
  /// servicio nativo ofrece directamente las cuentas que coinciden (ADR
  /// 0026). Un fallo solo significa que la próxima vez se vuelve a pedir
  /// desbloqueo, como antes.
  Future<void> _startNativeSession() async {
    try {
      final timeout = await ref.read(autoLockTimeoutSettingProvider.future);
      await _channel.invokeMethod('startSession', {
        'ttlMillis': timeout.duration.inMilliseconds,
        'trustedBrowsers': trustedBrowserPackages.toList(),
        'items': [
          for (final item in autofillSessionItems(widget.vault.entries))
            item.toChannel(),
        ],
      });
    } catch (_) {}
  }

  Future<Map<String, dynamic>> _fetchRequest() async {
    final result = await _channel.invokeMethod<Map<Object?, Object?>>(
      'getRequest',
    );
    return (result ?? const {}).map((key, value) => MapEntry('$key', value));
  }

  Future<void> _cancel() => _channel.invokeMethod('cancel');

  Future<void> _submitGet(VaultEntry entry) =>
      _channel.invokeMethod('submitGet', {
        'username': entry.fields['username'] ?? '',
        'password': entry.fields['password'] ?? '',
      });

  /// "Rellenar y recordar este sitio" (ADR 0020): la entrada pasa a
  /// coincidir sola la próxima vez, igual que al vincular desde la
  /// extensión (ADR 0015).
  Future<void> _linkSiteAndSubmit(VaultEntry entry, String origin) async {
    await ref
        .read(vaultEntriesControllerProvider)
        .updateEntry(
          id: entry.id,
          title: entry.title,
          fields: {...entry.fields, 'url': linkedUrlForOrigin(origin)},
        );
    await _submitGet(entry);
  }

  /// Con página web, la entrada nueva se titula con el sitio y guarda su
  /// URL, en vez del paquete del navegador (ADR 0020).
  Future<void> _submitCreate({
    required String packageName,
    required String? origin,
    required String username,
    required String password,
  }) async {
    await ref
        .read(vaultEntriesControllerProvider)
        .addEntry(
          title: origin != null ? Uri.parse(origin).host : packageName,
          fields: {
            'username': username,
            'password': password,
            if (origin != null) 'url': linkedUrlForOrigin(origin),
          },
        );
    await _channel.invokeMethod('submitCreate');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Lockspire'),
        leading: IconButton(icon: const Icon(Icons.close), onPressed: _cancel),
      ),
      body: SafeArea(
        child: FutureBuilder<Map<String, dynamic>>(
          future: _requestFuture,
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final request = snapshot.data!;
            final origin = webOriginFor(
              webDomain: request['webDomain'] as String?,
              webScheme: request['webScheme'] as String?,
            );
            return switch (request['mode']) {
              'get' => GetCredentialView(
                vault: widget.vault,
                packageName: request['packageName'] as String? ?? '',
                origin: origin,
                onFill: _submitGet,
                onLinkAndFill: _linkSiteAndSubmit,
              ),
              'create' => CreateCredentialView(
                packageName: request['packageName'] as String? ?? '',
                origin: origin,
                username: request['username'] as String? ?? '',
                password: request['password'] as String? ?? '',
                onSave: _submitCreate,
                onDismiss: _cancel,
              ),
              _ => Center(
                child: Padding(
                  padding: const EdgeInsets.all(LockspireSpacing.lg),
                  child: Text(
                    context.l10n.autofillBadRequest,
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            };
          },
        ),
      ),
    );
  }
}
