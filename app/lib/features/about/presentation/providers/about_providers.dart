// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Gabriel Ángel Montoya Rico

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../domain/ports/app_info_port.dart';
import '../../domain/ports/external_link_port.dart';
import '../../infrastructure/package_info_adapter.dart';
import '../../infrastructure/url_launcher_link_adapter.dart';

part 'about_providers.g.dart';

@Riverpod(keepAlive: true)
AppInfoPort appInfoPort(Ref ref) => const PackageInfoAdapter();

@Riverpod(keepAlive: true)
ExternalLinkPort externalLinkPort(Ref ref) => const UrlLauncherLinkAdapter();

/// Versión instalada, para mostrarla en Acerca de.
@Riverpod(keepAlive: true)
Future<AppVersion> appVersion(Ref ref) =>
    ref.watch(appInfoPortProvider).version();
