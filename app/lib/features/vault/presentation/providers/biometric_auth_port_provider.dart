// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Lockspire

import 'dart:io' show Platform;

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../domain/ports/biometric_auth_port.dart';
import '../../infrastructure/android_biometric_auth_adapter.dart';
import '../../infrastructure/unavailable_biometric_auth_adapter.dart';
import '../../infrastructure/windows_biometric_auth_adapter.dart';

part 'biometric_auth_port_provider.g.dart';

/// Composition root: elige el adaptador de [BiometricAuthPort] según la
/// plataforma — ver docs/adr/0010-desbloqueo-biometrico.md. Android usa
/// el gating biométrico nativo de `flutter_secure_storage`; Windows usa
/// `local_auth` (Windows Hello) + `flutter_secure_storage` plano;
/// cualquier otra plataforma queda deshabilitada, sin crashear.
@Riverpod(keepAlive: true)
BiometricAuthPort biometricAuthPort(Ref ref) {
  if (Platform.isAndroid) {
    return AndroidBiometricAuthAdapter(
      plainStorage: const FlutterSecureStorage(),
    );
  }
  if (Platform.isWindows) {
    return WindowsBiometricAuthAdapter(storage: const FlutterSecureStorage());
  }
  return const UnavailableBiometricAuthAdapter();
}
