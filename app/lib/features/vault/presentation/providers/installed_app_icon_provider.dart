// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Gabriel Ángel Montoya Rico

import 'package:flutter/services.dart';
import 'package:lockspire/shared/platform_capabilities.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'installed_app_icon_provider.g.dart';

const _channel = MethodChannel('com.lockspire.lockspire/app_icons');

/// Ícono de una app Android instalada (ADR 0029), leído del sistema sin
/// red. `null` fuera de Android o si la app no está instalada. Se guarda
/// en memoria mientras la app está abierta.
@Riverpod(keepAlive: true)
Future<Uint8List?> installedAppIcon(Ref ref, String packageName) async {
  if (!ref.watch(platformCapabilitiesProvider).isAndroid) return null;
  try {
    return await _channel.invokeMethod<Uint8List>('getAppIcon', {
      'package': packageName,
    });
  } catch (_) {
    return null;
  }
}
