// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Gabriel Ángel Montoya Rico

import 'package:flutter/services.dart';

import '../domain/appearance_preference.dart';
import '../domain/ports/launcher_icon_port.dart';

/// [LauncherIconPort] sobre el canal `launcher_icon` (`LauncherIcon.kt`).
class MethodChannelLauncherIcon implements LauncherIconPort {
  static const _channel = MethodChannel(
    'com.lockspire.lockspire/launcher_icon',
  );

  const MethodChannelLauncherIcon();

  @override
  Future<void> useThemeIcon(ThemeFamilyId family) async {
    try {
      await _channel.invokeMethod<bool>('setTheme', {'theme': family.name});
    } catch (_) {}
  }
}
