// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Gabriel Ángel Montoya Rico

import 'dart:typed_data';

/// Descarga el ícono de un sitio (ADR 0029) directamente del sitio, ya
/// reducido a un PNG pequeño. `null` si el sitio no tiene uno usable.
abstract class SiteIconFetcherPort {
  Future<Uint8List?> fetchPng(String host);
}

/// No se pudo conectar (sin red, DNS): el sitio no dijo nada todavía y se
/// reintenta en otro momento.
class SiteIconOfflineException implements Exception {
  const SiteIconOfflineException();
}
