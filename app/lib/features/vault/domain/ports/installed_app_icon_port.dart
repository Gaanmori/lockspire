// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Gabriel Ángel Montoya Rico

import 'dart:typed_data';

/// El ícono de una app instalada (Android), para las entradas que tienen
/// su paquete (ADR 0029). No se guarda en la bóveda: lo da el sistema.
abstract class InstalledAppIconPort {
  /// PNG del ícono de [packageName], o `null` si no está instalada.
  Future<Uint8List?> iconFor(String packageName);
}
