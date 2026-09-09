// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Lockspire

import 'package:flutter/material.dart';

/// Tokens de color del sistema de diseño (ver docs/design/README.md).
/// Dirección visual: cálido y cercano.
abstract final class LockspireColors {
  static const bgPage = Color(0xFFFFF8F1);
  static const bgSurface = Color(0xFFFFFFFF);
  static const bgSurfaceSubtle = Color(0xFFFDEDE6);
  static const bgInput = Color(0xFFF6ECE1);

  static const textPrimary = Color(0xFF3A2E2A);
  static const textSecondary = Color(0xFF8A7A73);
  static const textPlaceholder = Color(0xFFC9B8AF);

  static const accentDefault = Color(0xFFEA6C4D);
  static const accentHover = Color(0xFFD65A3C);
  static const accentSecondary = Color(0xFF4FA391);

  static const danger = Color(0xFFC23B3B);
}
