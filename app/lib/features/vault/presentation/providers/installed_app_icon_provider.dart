// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Gabriel Ángel Montoya Rico

import 'dart:typed_data';

import 'package:lockspire/shared/platform_capabilities.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../domain/ports/installed_app_icon_port.dart';
import '../../infrastructure/method_channel_app_icons.dart';

part 'installed_app_icon_provider.g.dart';

@Riverpod(keepAlive: true)
InstalledAppIconPort installedAppIconPort(Ref ref) =>
    const MethodChannelAppIcons();

/// Ícono de la app instalada [packageName]; `null` fuera de Android.
@Riverpod(keepAlive: true)
Future<Uint8List?> installedAppIcon(Ref ref, String packageName) async {
  if (!ref.watch(platformCapabilitiesProvider).isAndroid) return null;
  return ref.watch(installedAppIconPortProvider).iconFor(packageName);
}
