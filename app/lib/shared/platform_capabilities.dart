// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Lockspire

import 'dart:io' show Platform;

import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'platform_capabilities.g.dart';

/// Lo que la interfaz necesita saber de la plataforma, en un solo lugar
/// (revisión 2026-09-25, hallazgo C2). Las pantallas lo leen de
/// [platformCapabilitiesProvider] en vez de consultar `Platform.isX`, así
/// los tests pueden simular cualquier plataforma.
///
/// Elegir qué adaptador usar según la plataforma sigue en los providers de
/// cada feature: eso es composition root, no interfaz.
class PlatformCapabilities {
  /// Escritorio con bandeja del sistema (Windows, Linux; ADR 0012).
  final bool isDesktop;

  /// Android: autocompletado del sistema, Material You, bloqueo al salir.
  final bool isAndroid;

  /// Cómo se llama el desbloqueo biométrico en esta plataforma (ADR 0010).
  final String biometricMethodName;

  const PlatformCapabilities({
    required this.isDesktop,
    required this.isAndroid,
    required this.biometricMethodName,
  });

  factory PlatformCapabilities.current() => PlatformCapabilities(
    isDesktop: Platform.isWindows || Platform.isLinux,
    isAndroid: Platform.isAndroid,
    biometricMethodName: Platform.isWindows ? 'Windows Hello' : 'la huella',
  );
}

@Riverpod(keepAlive: true)
PlatformCapabilities platformCapabilities(Ref ref) =>
    PlatformCapabilities.current();
