// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Lockspire

/// Mensaje mal formado o que no cumple el esquema del protocolo. Nunca se
/// procesa un mensaje que haya lanzado esto (ADR 0013).
class BridgeProtocolException implements Exception {
  final String message;

  const BridgeProtocolException(this.message);

  @override
  String toString() => 'BridgeProtocolException: $message';
}
