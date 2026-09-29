// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Gabriel Ángel Montoya Rico

/// Cuenta de Google conectada para sync vía Drive.
///
/// [refreshToken] es `null` en Android — ahí la sesión la administra
/// `google_sign_in` internamente (Credential Manager/Play Services), no
/// hace falta guardar tokens propios. En Windows sí hace falta: no hay
/// sesión nativa, así que el refresh token guardado acá es lo único que
/// permite reconectar sin volver a abrir el navegador.
class GoogleDriveAccount {
  final String email;
  final String? refreshToken;

  const GoogleDriveAccount({required this.email, this.refreshToken});
}

/// Puerto de almacenamiento de la cuenta de Google conectada.
///
/// Las implementaciones deben usar el almacenamiento seguro del SO —
/// nunca texto plano en disco (mismo criterio que [SyncCredentialsPort]).
abstract class GoogleDriveAccountPort {
  Future<GoogleDriveAccount?> googleDriveAccount();

  Future<void> saveGoogleDriveAccount(GoogleDriveAccount account);

  Future<void> clearGoogleDriveAccount();
}
