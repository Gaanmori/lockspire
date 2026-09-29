// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Gabriel Ángel Montoya Rico

import 'package:flutter/services.dart';

import '../domain/ports/installed_app_icon_port.dart';

/// [InstalledAppIconPort] sobre el canal `app_icons` (`AppIcons.kt`).
class MethodChannelAppIcons implements InstalledAppIconPort {
  static const _channel = MethodChannel('com.lockspire.lockspire/app_icons');

  const MethodChannelAppIcons();

  @override
  Future<Uint8List?> iconFor(String packageName) async {
    try {
      return await _channel.invokeMethod<Uint8List>('getAppIcon', {
        'package': packageName,
      });
    } catch (_) {
      return null;
    }
  }
}
