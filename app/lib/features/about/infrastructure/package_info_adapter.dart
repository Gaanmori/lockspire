// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Gabriel Ángel Montoya Rico

import 'package:package_info_plus/package_info_plus.dart';

import '../domain/ports/app_info_port.dart';

/// [AppInfoPort] con `package_info_plus`.
class PackageInfoAdapter implements AppInfoPort {
  const PackageInfoAdapter();

  @override
  Future<AppVersion> version() async {
    final info = await PackageInfo.fromPlatform();
    return AppVersion(version: info.version, build: info.buildNumber);
  }
}
