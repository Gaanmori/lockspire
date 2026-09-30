// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Gabriel Ángel Montoya Rico

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lockspire/features/appearance/presentation/providers/launcher_icon_port_provider.dart';
import 'package:lockspire/features/about/infrastructure/package_info_adapter.dart';
import 'package:lockspire/features/about/infrastructure/url_launcher_link_adapter.dart';
import 'package:lockspire/features/about/presentation/providers/about_providers.dart';
import 'package:lockspire/features/appearance/infrastructure/method_channel_launcher_icon.dart';
import 'package:lockspire/features/autofill/infrastructure/method_channel_autofill_host.dart';
import 'package:lockspire/features/autofill/infrastructure/method_channel_autofill_settings.dart';
import 'package:lockspire/features/autofill/presentation/providers/autofill_host_port_provider.dart';
import 'package:lockspire/features/autofill/presentation/providers/system_autofill_settings_port_provider.dart';
import 'package:lockspire/features/desktop/infrastructure/themed_icon_file_adapter.dart';
import 'package:lockspire/features/desktop/presentation/providers/desktop_ports_providers.dart';
import 'package:lockspire/features/vault/infrastructure/asset_word_list_adapter.dart';
import 'package:lockspire/features/vault/infrastructure/file_picker_transfer_adapter.dart';
import 'package:lockspire/features/vault/infrastructure/http_site_icon_fetcher.dart';
import 'package:lockspire/features/vault/infrastructure/method_channel_app_icons.dart';
import 'package:lockspire/features/vault/presentation/providers/file_transfer_port_provider.dart';
import 'package:lockspire/features/vault/presentation/providers/installed_app_icon_provider.dart';
import 'package:lockspire/features/vault/presentation/providers/site_icons_providers.dart';
import 'package:lockspire/features/vault/presentation/providers/word_list_port_provider.dart';

/// La raíz de composición (ADR 0003, CLAUDE.md): cada puerto se resuelve a
/// su adaptador real cuando nadie lo sustituye. Los tests de flujo cambian
/// estos bordes por dobles; este test comprueba que, sin dobles, la app
/// conecta los de verdad.
void main() {
  late ProviderContainer container;

  setUp(() => container = ProviderContainer());
  tearDown(() => container.dispose());

  test('los puertos de plataforma usan sus adaptadores reales', () {
    expect(
      container.read(fileTransferPortProvider),
      isA<FilePickerTransferAdapter>(),
    );
    expect(container.read(appInfoPortProvider), isA<PackageInfoAdapter>());
    expect(
      container.read(externalLinkPortProvider),
      isA<UrlLauncherLinkAdapter>(),
    );
    expect(
      container.read(autofillHostPortProvider),
      isA<MethodChannelAutofillHost>(),
    );
    expect(
      container.read(systemAutofillSettingsPortProvider),
      isA<MethodChannelAutofillSettings>(),
    );
    expect(
      container.read(launcherIconPortProvider),
      isA<MethodChannelLauncherIcon>(),
    );
    expect(
      container.read(installedAppIconPortProvider),
      isA<MethodChannelAppIcons>(),
    );
    expect(
      container.read(themedIconFilePortProvider),
      isA<ThemedIconFileAdapter>(),
    );
    expect(container.read(wordListPortProvider), isA<AssetWordListAdapter>());
  });

  test('fuera de Google Play no se ofrece donar (ADR 0033)', () {
    expect(container.read(donationPortProvider), isNull);
  });

  test('los íconos de sitios van directo al sitio y el respaldo a '
      'DuckDuckGo (ADR 0029, 0030)', () {
    expect(
      container.read(siteIconFetcherPortProvider),
      isA<HttpSiteIconFetcher>(),
    );
    expect(
      container.read(siteIconFallbackFetcherPortProvider),
      isA<HttpSiteIconFetcher>(),
    );
  });
}
