// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Gabriel Ángel Montoya Rico

import 'package:lockspire/shared/secure_storage_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:lockspire/shared/presentation/preferences.dart';

import '../../domain/ports/site_icon_fetcher_port.dart';
import '../../domain/ports/site_icons_preferences_port.dart';
import '../../infrastructure/http_site_icon_fetcher.dart';
import '../../infrastructure/secure_storage_site_icons_adapter.dart';

part 'site_icons_providers.g.dart';

/// Composition root de los íconos de sitios (ADR 0029).
@Riverpod(keepAlive: true)
SiteIconFetcherPort siteIconFetcherPort(Ref ref) => HttpSiteIconFetcher();

/// Respaldo con DuckDuckGo para los que el sitio no ofrece (ADR 0030).
@Riverpod(keepAlive: true)
SiteIconFetcherPort siteIconFallbackFetcherPort(Ref ref) =>
    HttpSiteIconFetcher.duckDuckGo();

@Riverpod(keepAlive: true)
SiteIconsPreferencesPort siteIconsPreferencesPort(Ref ref) =>
    SecureStorageSiteIconsAdapter(ref.watch(secureStorageProvider));

/// Si el usuario activó los íconos de los sitios. Apagado por defecto.
@Riverpod(keepAlive: true)
class SiteIconsEnabled extends _$SiteIconsEnabled {
  @override
  Future<bool> build() => ref.watch(siteIconsPreferencesPortProvider).load();

  /// Se aplica al instante; si guardar falla, dura hasta cerrar la app.
  Future<void> set(bool enabled) async {
    state = AsyncData(enabled);
    await saveAppliedPreference(
      () => ref.read(siteIconsPreferencesPortProvider).save(enabled),
    );
  }
}

/// Si el usuario activó completar los que faltan con DuckDuckGo (ADR 0030).
@Riverpod(keepAlive: true)
class SiteIconsFallbackEnabled extends _$SiteIconsFallbackEnabled {
  @override
  Future<bool> build() =>
      ref.watch(siteIconsPreferencesPortProvider).loadFallback();

  Future<void> set(bool enabled) async {
    state = AsyncData(enabled);
    await saveAppliedPreference(
      () => ref.read(siteIconsPreferencesPortProvider).saveFallback(enabled),
    );
  }
}
