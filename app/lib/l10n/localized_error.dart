// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Gabriel Ángel Montoya Rico

import 'package:lockspire/features/sync/application/sync_vault_use_case.dart';
import 'package:lockspire/features/vault/application/change_master_password_use_case.dart';
import 'package:lockspire/features/vault/application/master_password_policy.dart';
import 'package:lockspire/features/vault/application/password_changed_elsewhere_port.dart';
import 'package:lockspire/features/vault/application/prepare_import_use_case.dart';
import 'package:lockspire/features/vault/application/save_vault_use_case.dart';
import 'package:lockspire/features/vault/application/vault_transfer_use_cases.dart';
import 'package:lockspire/features/vault/domain/vault_file_codec.dart';
import 'package:lockspire/shared/domain/app_problem.dart';

import 'generated/app_localizations.dart';

/// Mensaje para el usuario, en su idioma, de un error de cualquier capa
/// (ADR 0032). Un error que no es de la app (red, plataforma) se muestra
/// tal cual: su texto viene del sistema y no se puede traducir aquí.
String localizeError(AppLocalizations l10n, Object error) => switch (error) {
  AppProblem(:final code, :final detail) => _problem(l10n, code, detail),
  SyncHomeMismatchException(:final vaultHome, :final active) =>
    l10n.errorSyncHomeMismatch(
      syncProviderName(vaultHome),
      syncProviderName(active),
    ),
  RemoteVaultRejectedException(:final reason) => switch (reason) {
    RemoteVaultRejection.differentVault => l10n.errorRemoteDifferentVault,
    RemoteVaultRejection.notAuthentic => l10n.errorRemoteNotAuthentic,
    RemoteVaultRejection.passwordChanged => l10n.errorRemotePasswordChanged,
    RemoteVaultRejection.rollback => l10n.errorRemoteRollback,
  },
  IncorrectMasterPasswordException() => l10n.errorIncorrectCurrentPassword,
  WeakMasterPasswordException(:final problem) => localizeMasterPasswordProblem(
    l10n,
    problem,
  ),
  PreviousPasswordRequiredException() => l10n.errorPreviousPasswordRequired,
  IncorrectPreviousPasswordException() => l10n.errorIncorrectPreviousPassword,
  UnknownImportFormatException(:final extension) =>
    l10n.errorUnknownImportFormat(extension),
  VaultWriteConflictException() => l10n.errorVaultWriteConflict,
  IncorrectBackupPasswordException() => l10n.errorIncorrectBackupPassword,
  UnsupportedVaultFormatException(:final fileFormatMinReaderVersion) =>
    l10n.errorUnsupportedVaultFormat(fileFormatMinReaderVersion),
  UnsafeKdfParamsException() => l10n.errorUnsafeKdfParams,
  _ => '$error',
};

/// Por qué no se acepta una contraseña maestra (ADR 0018).
String localizeMasterPasswordProblem(
  AppLocalizations l10n,
  MasterPasswordProblem problem,
) => switch (problem) {
  MasterPasswordProblem.tooShort => l10n.masterPasswordTooShort(
    masterPasswordMinLength,
  ),
  MasterPasswordProblem.tooRepetitive => l10n.masterPasswordTooRepetitive,
  MasterPasswordProblem.tooWeak => l10n.masterPasswordTooWeak,
};

String _problem(AppLocalizations l10n, AppProblemCode code, String? detail) {
  final d = detail ?? '';
  return switch (code) {
    AppProblemCode.vaultLocked => l10n.errorVaultLocked,
    AppProblemCode.notAVaultFile => l10n.errorNotAVaultFile,
    AppProblemCode.syncNotConfigured => l10n.errorSyncNotConfigured,
    AppProblemCode.syncNothingToSync => l10n.errorSyncNothingToSync,
    AppProblemCode.syncConnectFailed => l10n.errorSyncConnectFailed(d),
    AppProblemCode.syncConnectVaultCloud => l10n.errorSyncConnectVaultCloud,
    AppProblemCode.remoteVaultMissing => l10n.errorRemoteVaultMissing(d),
    AppProblemCode.remoteUploadFailed => l10n.errorRemoteUploadFailed(d),
    AppProblemCode.webdavInsecureUrl => l10n.errorWebdavInsecureUrl,
    AppProblemCode.webdavInvalidUrl => l10n.errorWebdavInvalidUrl,
    AppProblemCode.accountEmailUnreadable => l10n.errorAccountEmailUnreadable(
      d,
    ),
    AppProblemCode.oauthBrowserFailed => l10n.errorOauthBrowserFailed,
    AppProblemCode.oauthTimedOut => l10n.errorOauthTimedOut(d),
    AppProblemCode.oauthNoCode => detail ?? l10n.errorOauthNoCode,
    AppProblemCode.oauthLoginClosed => l10n.errorOauthLoginClosed,
    AppProblemCode.oauthTokenFailed => l10n.errorOauthTokenFailed(d),
    AppProblemCode.oauthRefreshFailed => l10n.errorOauthRefreshFailed(d),
    AppProblemCode.nativeHostMissing => l10n.errorNativeHostMissing(d),
    AppProblemCode.nativeHostElevationCancelled =>
      l10n.errorNativeHostElevationCancelled,
    AppProblemCode.nativeHostWindowsOnly => l10n.errorNativeHostWindowsOnly,
    AppProblemCode.noSupportedBrowser => l10n.errorNoSupportedBrowser,
    AppProblemCode.importInvalidJson => l10n.errorImportInvalidJson,
    AppProblemCode.importNotBitwardenJson => l10n.errorImportNotBitwardenJson,
    AppProblemCode.importBitwardenEncrypted =>
      l10n.errorImportBitwardenEncrypted,
    AppProblemCode.importCsvUnclosedQuote => l10n.errorImportCsvUnclosedQuote,
    AppProblemCode.importCsvEmpty => l10n.errorImportCsvEmpty,
    AppProblemCode.importCsvNoPasswordColumn =>
      l10n.errorImportCsvNoPasswordColumn,
  };
}
