// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Gabriel Ángel Montoya Rico

import 'package:url_launcher/url_launcher.dart';

import '../domain/ports/external_link_port.dart';

/// [ExternalLinkPort] con `url_launcher`, siempre en la app externa (el
/// navegador), nunca en una vista dentro de Lockspire.
class UrlLauncherLinkAdapter implements ExternalLinkPort {
  const UrlLauncherLinkAdapter();

  @override
  Future<bool> open(Uri url) =>
      launchUrl(url, mode: LaunchMode.externalApplication);
}
