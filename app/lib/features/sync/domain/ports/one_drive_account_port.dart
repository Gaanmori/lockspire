// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Lockspire

/// Cuenta de Microsoft conectada para sync vía OneDrive.
///
/// A diferencia de [GoogleDriveAccount] (donde `refreshToken` es `null`
/// en Android porque `google_sign_in` administra la sesión nativa),
/// acá **siempre** hay un refresh token guardado — no hay ninguna
/// plataforma con sesión nativa que lo haga innecesario, el flujo de
/// autenticación es el mismo (loopback + PKCE) en Android y Windows, ver
/// `microsoft_oauth_auth.dart`.
class OneDriveAccount {
  final String email;
  final String refreshToken;

  const OneDriveAccount({required this.email, required this.refreshToken});
}

/// Puerto de almacenamiento de la cuenta de Microsoft conectada.
///
/// Las implementaciones deben usar el almacenamiento seguro del SO —
/// nunca texto plano en disco (mismo criterio que
/// [GoogleDriveAccountPort]/[SyncCredentialsPort]).
abstract class OneDriveAccountPort {
  Future<OneDriveAccount?> oneDriveAccount();

  Future<void> saveOneDriveAccount(OneDriveAccount account);

  Future<void> clearOneDriveAccount();
}
