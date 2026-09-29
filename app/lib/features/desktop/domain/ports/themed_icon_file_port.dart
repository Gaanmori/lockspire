// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Gabriel Ángel Montoya Rico

import 'package:lockspire/design/lockspire_icon.dart';

/// Archivo del ícono de Lockspire con los colores del tema, para la ventana
/// y la bandeja (el sistema los pide como archivo).
abstract class ThemedIconFilePort {
  /// Ruta del archivo para [colors]; se genera si no existe.
  Future<String> write(LockspireIconColors colors);
}
