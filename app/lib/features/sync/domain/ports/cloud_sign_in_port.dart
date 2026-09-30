// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Gabriel Ángel Montoya Rico

/// Una cuenta de nube recién conectada.
class CloudSignIn {
  final String email;

  /// `null` si la sesión la guarda el sistema operativo (Google en
  /// Android).
  final String? refreshToken;

  const CloudSignIn({required this.email, this.refreshToken});
}

/// Iniciar y cerrar sesión en una nube con OAuth (Google Drive, OneDrive).
/// La pantalla de sync no conoce cómo lo hace cada plataforma: navegador
/// con loopback en escritorio, `google_sign_in` en Android, dirección
/// propia de la app para Microsoft en Android (revisión 2026-09-30, A12).
abstract class CloudSignInPort {
  /// Interactivo: abre el navegador o el selector de cuentas. Solo desde un
  /// botón que tocó el usuario.
  Future<CloudSignIn> connect();

  /// Revoca el permiso si la plataforma lo guarda; si no, no hace nada (el
  /// refresh token lo borra quien guarda la cuenta).
  Future<void> disconnect();
}
