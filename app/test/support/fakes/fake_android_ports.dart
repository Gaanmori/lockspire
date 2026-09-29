// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Gabriel Ángel Montoya Rico

import 'dart:typed_data';

import 'package:lockspire/features/appearance/domain/appearance_preference.dart';
import 'package:lockspire/features/appearance/domain/ports/launcher_icon_port.dart';
import 'package:lockspire/features/autofill/domain/ports/system_autofill_settings_port.dart';
import 'package:lockspire/features/vault/domain/ports/installed_app_icon_port.dart';

class FakeAutofillSettings implements SystemAutofillSettingsPort {
  int opened = 0;
  bool canOpen = true;

  @override
  Future<bool> open() async {
    if (canOpen) opened++;
    return canOpen;
  }
}

/// Registra cada ícono de lanzador pedido, en orden.
class FakeLauncherIcon implements LauncherIconPort {
  final themes = <ThemeFamilyId>[];

  @override
  Future<void> useThemeIcon(ThemeFamilyId family) async => themes.add(family);
}

/// Íconos de apps "instaladas": [icons] por paquete.
class FakeInstalledAppIcons implements InstalledAppIconPort {
  final icons = <String, Uint8List>{};

  @override
  Future<Uint8List?> iconFor(String packageName) async => icons[packageName];
}
