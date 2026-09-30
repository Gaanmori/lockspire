// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Gabriel Ángel Montoya Rico

import 'dart:io' show Platform;

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../domain/ports/profile_registry_port.dart';
import '../domain/profile.dart';
import '../infrastructure/secure_storage_profile_registry_adapter.dart';

/// El perfil con que arranca la app (ADR 0039): el último usado, si los
/// perfiles están activados; si no, el principal. Se lee antes de crear el
/// primer contenedor, que ya es de ese perfil.
Future<String> startProfileId({
  ProfileRegistryPort? registry,
  bool? enabledByDefault,
}) async {
  final port =
      registry ??
      const SecureStorageProfileRegistryAdapter(FlutterSecureStorage());
  final loaded = await port.load(mainName: '');
  final enabled = loaded.isEnabled(
    defaultEnabled: enabledByDefault ?? !Platform.isAndroid,
  );
  return enabled ? loaded.lastUsed.id : mainProfileId;
}
