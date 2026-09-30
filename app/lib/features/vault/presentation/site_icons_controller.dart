// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Gabriel Ángel Montoya Rico

import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../application/fetch_site_icons_use_case.dart';
import '../domain/site_icons.dart';
import '../domain/vault_event.dart';
import 'providers/site_icons_providers.dart';
import 'providers/vault_events_provider.dart';
import 'vault_session_controller.dart';
import 'vault_session_state.dart';

part 'site_icons_controller.g.dart';

/// Con los íconos activados, busca los que faltan al abrir la bóveda y
/// después de cada guardado (una entrada nueva con sitio), y los guarda en
/// la bóveda de una vez (ADR 0029). Se instancia al arrancar la app
/// (`main.dart`), no en el autocompletado.
@Riverpod(keepAlive: true)
SiteIconsController siteIconsController(Ref ref) {
  final controller = SiteIconsController._(ref);
  final subscription = ref
      .read(vaultEventsProvider)
      .events
      .listen(controller._onVaultEvent);
  ref.listen(siteIconsEnabledProvider, (_, next) {
    if (next.value == true) unawaited(controller.refresh());
  });
  ref.listen(siteIconsFallbackEnabledProvider, (_, next) {
    if (next.value == true) unawaited(controller.refresh());
  });
  ref.onDispose(subscription.cancel);
  return controller;
}

class SiteIconsController {
  final Ref _ref;
  bool _running = false;

  SiteIconsController._(this._ref);

  void _onVaultEvent(VaultEvent event) {
    if (event == VaultEvent.unlocked || event == VaultEvent.saved) {
      unawaited(refresh());
    }
  }

  /// Busca los íconos que faltan. Silencioso: un fallo de red solo deja
  /// las letras, nunca un error que el usuario no pidió ver.
  Future<void> refresh() async {
    if (_running) return;
    _running = true;
    try {
      if (await _enabled() != true) return;
      final session = _ref.read(vaultSessionControllerProvider).value;
      if (session is! VaultSessionUnlocked) return;
      // 1. Directo de cada sitio.
      final found = await FetchSiteIconsUseCase(
        fetcher: _ref.read(siteIconFetcherPortProvider),
      ).call(hostsMissingIcons(session.vault));
      // 2. Si está activado, DuckDuckGo para los que el sitio no ofrece
      //    (ADR 0030): recibe solo esos dominios.
      if (await _fallbackEnabled()) {
        found.addAll(
          await FetchSiteIconsUseCase(
            fetcher: _ref.read(siteIconFallbackFetcherPortProvider),
            missingMarker: noIconAnywhere,
          ).call(hostsForIconFallback(session.vault.withSiteIcons(found))),
        );
      }
      if (found.isEmpty) return;
      await _ref
          .read(vaultSessionControllerProvider.notifier)
          .updateVault((vault) => vault.withSiteIcons(found));
    } catch (_) {
      // Ver arriba.
    } finally {
      _running = false;
    }
  }

  // El valor actual de cada preferencia; se espera la carga solo si todavía
  // no terminó. `.future` no sirve después de cargar: sigue devolviendo lo
  // que se leyó al arrancar, no lo que el usuario acaba de elegir, y activar
  // los íconos no buscaba nada hasta el siguiente guardado (encontrado por
  // un test de flujo, 2026-09-29).
  Future<bool> _enabled() async =>
      _ref.read(siteIconsEnabledProvider).value ??
      await _ref.read(siteIconsEnabledProvider.future);

  Future<bool> _fallbackEnabled() async =>
      _ref.read(siteIconsFallbackEnabledProvider).value ??
      await _ref.read(siteIconsFallbackEnabledProvider.future);

  /// "Volver a buscar": olvida los sitios marcados sin ícono.
  Future<void> retryMissing() => _ref
      .read(vaultSessionControllerProvider.notifier)
      .updateVault((vault) => vault.withoutMissingSiteIcons());
}
