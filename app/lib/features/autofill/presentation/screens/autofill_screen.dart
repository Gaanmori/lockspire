// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Gabriel Ángel Montoya Rico

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../design/lockspire_spacing.dart';
import '../../../vault/domain/entities/vault.dart';
import '../../../vault/domain/entities/vault_entry.dart';
import '../../../vault/presentation/vault_entries_controller.dart';
import '../../../browser_bridge/domain/origin_matcher.dart';
import '../../../vault/presentation/providers/auto_lock_timeout_setting_provider.dart';
import '../../domain/autofill_session.dart';
import '../../domain/autofill_web_origin.dart';
import '../../domain/ports/autofill_host_port.dart';
import '../providers/autofill_host_port_provider.dart';
import '../widgets/get_credential_view.dart';
import '../widgets/create_credential_view.dart';
import 'package:lockspire/l10n/l10n.dart';
import '../../../vault/domain/entities/entry_fields.dart';

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
  late final AutofillHostPort _host = ref.read(autofillHostPortProvider);
  late final Future<AutofillRequest> _request = _host.request();

  @override
  void initState() {
    super.initState();
    _startNativeSession();
  }

  /// Se desbloqueó para rellenar: durante el tiempo del auto-bloqueo, el
  /// servicio nativo ofrece directamente las cuentas que coinciden (ADR
  /// 0026). Un fallo solo significa que la próxima vez se vuelve a pedir
  /// desbloqueo, como antes.
  Future<void> _startNativeSession() async {
    try {
      final timeout = await ref.read(autoLockTimeoutSettingProvider.future);
      await _host.startSession(
        ttl: timeout.duration,
        trustedBrowsers: trustedBrowserPackages.toSet(),
        items: autofillSessionItems(widget.vault.entries).toList(),
      );
    } catch (_) {
      // Ver arriba: la próxima vez se vuelve a pedir desbloquear.
    }
  }

  Future<void> _cancel() => _host.cancel();

  Future<void> _submitGet(VaultEntry entry) => _host.fill(
    username: entry.fields[EntryFields.username] ?? '',
    password: entry.fields[EntryFields.password] ?? '',
  );

  /// "Rellenar y recordar este sitio" (ADR 0020): la entrada pasa a
  /// coincidir sola la próxima vez, igual que al vincular desde la
  /// extensión (ADR 0015).
  Future<void> _linkSiteAndSubmit(VaultEntry entry, String origin) async {
    await ref
        .read(vaultEntriesControllerProvider)
        .updateEntry(
          id: entry.id,
          title: entry.title,
          fields: {
            ...entry.fields,
            EntryFields.url: linkedUrlForOrigin(origin),
          },
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
            EntryFields.username: username,
            EntryFields.password: password,
            if (origin != null) EntryFields.url: linkedUrlForOrigin(origin),
          },
        );
    await _host.confirmSaved();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Lockspire'),
        leading: IconButton(icon: const Icon(Icons.close), onPressed: _cancel),
      ),
      body: SafeArea(
        child: FutureBuilder<AutofillRequest>(
          future: _request,
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            return switch (snapshot.data!) {
              AutofillFillRequest(:final packageName, :final origin) =>
                GetCredentialView(
                  vault: widget.vault,
                  packageName: packageName,
                  origin: origin,
                  onFill: _submitGet,
                  onLinkAndFill: _linkSiteAndSubmit,
                ),
              AutofillSaveRequest(
                :final packageName,
                :final origin,
                :final username,
                :final password,
              ) =>
                CreateCredentialView(
                  packageName: packageName,
                  origin: origin,
                  username: username,
                  password: password,
                  onSave: _submitCreate,
                  onDismiss: _cancel,
                ),
              AutofillUnknownRequest() => Center(
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
