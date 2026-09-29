// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Gabriel Ángel Montoya Rico

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../domain/ports/biometric_auth_port.dart';
import 'biometric_auth_port_provider.dart';

part 'biometric_status_provider.g.dart';

/// Si el dispositivo ofrece biometría y si está activada (hay clave
/// guardada). Quien activa, desactiva o reemplaza la clave lo invalida: así
/// Seguridad, que las pestañas mantienen construida, no queda mostrando el
/// estado del arranque (encontrado por un test de flujo, 2026-09-29).
@Riverpod(keepAlive: true)
Future<(BiometricAvailability, bool)> biometricStatus(Ref ref) async {
  final port = ref.watch(biometricAuthPortProvider);
  return (await port.checkAvailability(), await port.hasStoredKey());
}
