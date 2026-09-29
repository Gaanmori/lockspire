// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Gabriel Ángel Montoya Rico

/// La contraseña maestra ingresada no abre la bóveda: la clave derivada no
/// pasa la autenticación del cifrado. Es el único error que la interfaz
/// muestra como "Contraseña incorrecta"; cualquier otro (archivo ilegible,
/// bóveda dañada) tiene su propio mensaje.
class IncorrectMasterPasswordException implements Exception {
  const IncorrectMasterPasswordException();

  @override
  String toString() => 'IncorrectMasterPasswordException';
}
