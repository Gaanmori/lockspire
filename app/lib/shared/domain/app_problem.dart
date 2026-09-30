// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Gabriel Ángel Montoya Rico

/// Qué salió mal, para mostrárselo al usuario en su idioma (ADR 0032).
///
/// Dominio, casos de uso y adaptadores no conocen el idioma de la app: lanzan
/// un [AppProblem] con su [AppProblemCode], y la presentación lo traduce con
/// `localizeError`. [detail] lleva datos que no se traducen (el mensaje de un
/// servidor, una ruta, un código HTTP, el nombre de un proveedor).
enum AppProblemCode {
  vaultLocked,
  notAVaultFile,
  syncNotConfigured,
  syncNothingToSync,
  syncConnectFailed,
  syncConnectVaultCloud,
  remoteVaultMissing,
  remoteUploadFailed,
  webdavInsecureUrl,
  webdavInvalidUrl,
  accountEmailUnreadable,
  oauthBrowserFailed,
  oauthTimedOut,
  oauthNoCode,
  oauthLoginClosed,
  oauthTokenFailed,
  oauthRefreshFailed,
  nativeHostMissing,
  nativeHostElevationCancelled,
  nativeHostWindowsOnly,
  noSupportedBrowser,
  importInvalidJson,
  importNotBitwardenJson,
  importBitwardenEncrypted,
  importCsvUnclosedQuote,
  importCsvEmpty,
  importCsvNoPasswordColumn,
  profileNameEmpty,
  profileNameTooLong,
  profileNameTaken,
  profileMainNotRemovable,
  profilesInUse,
}

class AppProblem implements Exception {
  final AppProblemCode code;
  final String? detail;

  const AppProblem(this.code, {this.detail});

  @override
  String toString() => detail == null
      ? 'AppProblem(${code.name})'
      : 'AppProblem(${code.name}: $detail)';
}
