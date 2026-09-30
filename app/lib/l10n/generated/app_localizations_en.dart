// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Lockspire';

  @override
  String get appearanceTitle => 'Appearance';

  @override
  String get appearanceMode => 'Mode';

  @override
  String get appearanceModeSystem => 'System';

  @override
  String get appearanceModeLight => 'Light';

  @override
  String get appearanceModeDark => 'Dark';

  @override
  String get appearanceModeSystemHint =>
      'Switches between light and dark to match your system.';

  @override
  String get appearanceTheme => 'Theme';

  @override
  String get appearanceLauncherIconNote =>
      'The Lockspire icon on your phone also changes to the chosen theme within a few seconds. Some launchers remove the home screen shortcut when it changes: add it again from the app list.';

  @override
  String get themeSystemColors => 'System colors';

  @override
  String get themeGroupLockspire => 'Lockspire';

  @override
  String get themeGroupAutomatic => 'Automatic';

  @override
  String get themeGroupOperatingSystems => 'Inspired by operating systems';

  @override
  String get themeGrafitoHint =>
      'Understated, goes with everything. The default.';

  @override
  String get themeCustom => 'Custom';

  @override
  String get themeCustomHint =>
      'Choose any color: Lockspire builds the light and dark palette.';

  @override
  String get themeCustomHex => 'Hex color';

  @override
  String get themeCustomApply => 'Use this color';

  @override
  String get themeCustomInvalid => 'Enter a color like #6750A4.';

  @override
  String get themeSystemUnavailable =>
      'Not available on this device: Lineage is used instead.';

  @override
  String get themeSystemAndroid => 'Material You: colors from your wallpaper.';

  @override
  String get themeSystemDesktop => 'System accent color.';

  @override
  String appearanceThemeSemantics(Object title) {
    return 'Theme $title';
  }

  @override
  String get appearanceInUse => 'In use';

  @override
  String get appearanceLanguage => 'Language';

  @override
  String syncConnectFailed(Object provider, Object error) {
    return 'Could not connect to $provider: $error';
  }

  @override
  String syncMoveTitle(Object target) {
    return 'Move the vault to $target?';
  }

  @override
  String syncMoveBody(Object home, Object target) {
    return 'Your vault syncs with $home. If you continue, it will sync with $target instead, and a notice is left in $home.\n\nYour other devices will get that notice the next time they sync, and will need to connect $target to keep going. Nothing is lost: whatever is in $target is merged into this vault.';
  }

  @override
  String get commonCancel => 'Cancel';

  @override
  String get syncMoveConfirm => 'Move';

  @override
  String get syncReplaceRemoteTitle => 'Replace the cloud copy?';

  @override
  String get syncReplaceRemoteBody =>
      'The cloud has an older version than this device. If you restored an old copy on purpose, you can replace it with this device\'s version: you won\'t lose anything you have here.\n\nIf it wasn\'t you, someone may have accessed your cloud account: change that password before continuing.';

  @override
  String get syncReplaceConfirm => 'Replace';

  @override
  String get syncResultUploaded => 'The vault was uploaded to the server.';

  @override
  String get syncResultDownloaded =>
      'The vault was downloaded from the server.';

  @override
  String get syncResultUpToDate => 'Already up to date, nothing to do.';

  @override
  String syncResultMergedFields(int fieldConflictsResolved) {
    String _temp0 = intl.Intl.pluralLogic(
      fieldConflictsResolved,
      locale: localeName,
      other: '$fieldConflictsResolved fields were resolved automatically',
      one: '1 field was resolved automatically',
    );
    return 'Changes were merged: $_temp0 (you can see the previous value in that entry\'s history).';
  }

  @override
  String syncResultMergedEntries(int autoResolvedCount) {
    String _temp0 = intl.Intl.pluralLogic(
      autoResolvedCount,
      locale: localeName,
      other: '$autoResolvedCount entries resolved automatically',
      one: '1 entry resolved automatically',
    );
    return 'Changes were merged: $_temp0.';
  }

  @override
  String get syncResultMerged => 'Changes were merged.';

  @override
  String syncResultMoved(Object provider) {
    return 'Your vault moved to $provider. Connect it above to keep syncing.';
  }

  @override
  String get syncWebdavUrl => 'WebDAV server URL';

  @override
  String get syncWebdavUrlRequired => 'Enter the server URL';

  @override
  String get syncWebdavHttpsRequired =>
      'Use https://: with http:// your server username and password would travel unencrypted.';

  @override
  String get syncWebdavUrlInvalid =>
      'Enter a full URL, e.g. https://server/dav';

  @override
  String get syncWebdavUser => 'Username';

  @override
  String get syncWebdavUserRequired => 'Enter the username';

  @override
  String get syncWebdavPassword => 'Password';

  @override
  String get syncWebdavPasswordUnchanged => '(unchanged if left empty)';

  @override
  String get syncWebdavPasswordRequired => 'Enter the password';

  @override
  String get commonSave => 'Save';

  @override
  String get syncTitle => 'Sync';

  @override
  String get syncGoogleScopeNote =>
      'Lockspire only accesses its own hidden data folder in your Drive: it can\'t see the rest of your files.';

  @override
  String get syncConnectGoogle => 'Connect with Google';

  @override
  String get syncOneDriveScopeNote =>
      'Lockspire only accesses its own special app folder in your OneDrive: it can\'t see the rest of your files.';

  @override
  String get syncConnectOneDrive => 'Connect with OneDrive';

  @override
  String commonErrorDetail(Object error) {
    return 'An error occurred: $error';
  }

  @override
  String get syncNow => 'Sync now';

  @override
  String syncFailed(Object error) {
    return 'Could not sync: $error';
  }

  @override
  String get syncUploadLocal => 'Upload this device\'s version';

  @override
  String get restoreNoProvider => 'Set up a sync provider first.';

  @override
  String restoreSearchFailed(Object error) {
    return 'Could not look for the remote vault: $error';
  }

  @override
  String get restoreTitle => 'Restore existing vault';

  @override
  String get restoreIntro =>
      'Connect the same sync provider you already use on your other device: we\'ll download your vault from there.';

  @override
  String get restoreSetUpProvider => 'Set up sync provider';

  @override
  String get restoreFindVault => 'Find my vault';

  @override
  String get restoreSearching => 'Looking for your vault…';

  @override
  String get restoreSearchingDetail => 'Checking the configured sync provider.';

  @override
  String get restoreNotFoundTitle => 'There\'s no vault there yet';

  @override
  String get restoreNotFoundBody =>
      'The provider is connected, but we couldn\'t find any uploaded vault. If the other device hasn\'t synced yet, try from there first.';

  @override
  String get commonBack => 'Back';

  @override
  String get restoreFoundTitle => 'We found your vault';

  @override
  String get restoreFoundBody => 'Enter your master password to unlock it.';

  @override
  String get commonMasterPassword => 'Master password';

  @override
  String get commonMasterPasswordRequired => 'Enter your master password';

  @override
  String get commonWrongPassword => 'Wrong password';

  @override
  String get restoreConfirm => 'Restore vault';

  @override
  String cloudNotConnected(Object scopeNote) {
    return 'No account connected. $scopeNote';
  }

  @override
  String cloudConnectedAs(Object email) {
    return 'Connected as $email';
  }

  @override
  String get cloudDisconnect => 'Disconnect';

  @override
  String get pwChangedBanner =>
      'The master password was changed on another device. Enter the new one to keep syncing.';

  @override
  String get pwChangedEnterNew => 'Enter new password';

  @override
  String get pwChangedNotNew => 'That\'s not the new password';

  @override
  String commonCouldNotComplete(Object error) {
    return 'Could not complete: $error';
  }

  @override
  String get pwChangedDialogTitle => 'New master password';

  @override
  String get pwChangedDialogBody =>
      'Enter the password you set on the other device. The changes you made here are kept.';

  @override
  String get pwChangedNewPassword => 'New password';

  @override
  String get commonContinue => 'Continue';

  @override
  String syncHomeMovedBanner(Object provider) {
    return 'Your vault moved to $provider. Connect $provider on this device to keep syncing.';
  }

  @override
  String get syncHomeGoToSync => 'Go to Sync';

  @override
  String errorSyncHomeMismatch(Object home, Object active) {
    return 'Your vault syncs with $home, but this device is connected to $active. Connect $home in Sync to keep going.';
  }

  @override
  String get errorRemoteDifferentVault =>
      'The cloud has a different vault than yours. Nothing was changed on this device.';

  @override
  String get errorRemoteNotAuthentic =>
      'The cloud vault could not be verified (it is damaged, was modified, or uses another password). Nothing was changed on this device.';

  @override
  String get errorRemotePasswordChanged =>
      'The master password was changed on another device. Enter the new password to keep syncing.';

  @override
  String get errorRemoteRollback =>
      'The cloud has an older version than the one this device already synced: it may be an old copy that was restored, or tampering. Nothing was changed on this device.';

  @override
  String get errorIncorrectCurrentPassword =>
      'The current password is not correct.';

  @override
  String get errorPreviousPasswordRequired =>
      'This device has unsynced changes. Also enter the previous password to keep them.';

  @override
  String get errorIncorrectPreviousPassword =>
      'The previous password is not correct.';

  @override
  String errorUnknownImportFormat(Object extension) {
    return 'Unrecognized format: .$extension. Use a SafeInCloud XML, a CSV, a Bitwarden JSON or a .lockspire backup.';
  }

  @override
  String get errorVaultWriteConflict =>
      'The vault changed on disk since it was opened and was not overwritten. Open it again before saving.';

  @override
  String get errorIncorrectBackupPassword =>
      'The password does not open this backup. It is the master password the vault had when the backup was made.';

  @override
  String errorUnsupportedVaultFormat(int version) {
    return 'This vault was created with a newer version of Lockspire (format $version). Update the app to open it.';
  }

  @override
  String get errorUnsafeKdfParams =>
      'The vault file asks for unusual encryption parameters. It may be damaged or modified; it was not opened.';

  @override
  String masterPasswordTooShort(int count) {
    return 'Use at least $count characters';
  }

  @override
  String get masterPasswordTooRepetitive =>
      'It has too many repeated characters';

  @override
  String get masterPasswordTooWeak =>
      'It is too easy to guess: add words, capital letters, numbers or symbols';

  @override
  String get errorVaultLocked => 'The vault must be unlocked.';

  @override
  String get errorNotAVaultFile => 'This is not a valid Lockspire vault file.';

  @override
  String get errorSyncNotConfigured =>
      'Set up a sync provider first (WebDAV, Google Drive or OneDrive).';

  @override
  String get errorSyncNothingToSync =>
      'There is no vault on this device or in the cloud.';

  @override
  String errorSyncConnectFailed(Object provider) {
    return 'Could not connect to $provider.';
  }

  @override
  String get errorSyncConnectVaultCloud =>
      'Connect your vault\'s cloud in Sync.';

  @override
  String errorRemoteVaultMissing(Object provider) {
    return 'There is no vault in $provider yet.';
  }

  @override
  String errorRemoteUploadFailed(Object provider) {
    return 'Could not upload the vault to $provider.';
  }

  @override
  String get errorWebdavInsecureUrl =>
      'The WebDAV server uses unencrypted http://. Change the URL to https:// in Sync.';

  @override
  String get errorWebdavInvalidUrl => 'The WebDAV server URL is not valid.';

  @override
  String errorAccountEmailUnreadable(Object provider) {
    return 'Could not read the $provider account email.';
  }

  @override
  String get errorOauthBrowserFailed => 'Could not open the system browser.';

  @override
  String errorOauthTimedOut(Object provider) {
    return 'Signing in to $provider timed out. Try again.';
  }

  @override
  String get errorOauthNoCode => 'No authorization code was received.';

  @override
  String get errorOauthLoginClosed => 'Waiting for sign-in was closed.';

  @override
  String errorOauthTokenFailed(Object detail) {
    return 'Could not get access to OneDrive: $detail';
  }

  @override
  String errorOauthRefreshFailed(Object detail) {
    return 'Could not renew the OneDrive session: $detail';
  }

  @override
  String errorNativeHostMissing(Object path) {
    return 'The browser connection component was not found at $path. Reinstall Lockspire.';
  }

  @override
  String get errorNativeHostElevationCancelled =>
      'Registration for the whole computer was not completed (was the administrator prompt cancelled?).';

  @override
  String get errorNativeHostWindowsOnly => 'Only available on Windows for now.';

  @override
  String get errorNoSupportedBrowser => 'No compatible browser was found.';

  @override
  String get errorImportInvalidJson => 'The file is not valid JSON.';

  @override
  String get errorImportNotBitwardenJson =>
      'This is not a Bitwarden JSON export.';

  @override
  String get errorImportBitwardenEncrypted =>
      'This Bitwarden JSON is encrypted. Export it again choosing \"JSON\" (unencrypted) to import it.';

  @override
  String get errorImportCsvUnclosedQuote => 'The CSV has unclosed quotes.';

  @override
  String get errorImportCsvEmpty => 'The CSV is empty.';

  @override
  String get errorImportCsvNoPasswordColumn =>
      'No password column was found. Export from your manager as CSV (Bitwarden, Chrome, Firefox or KeePassXC).';

  @override
  String get biometricWindowsHello => 'Windows Hello';

  @override
  String get biometricFingerprint => 'your fingerprint';

  @override
  String get crackTimeInstant => 'instant';

  @override
  String crackTimeSeconds(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count seconds',
      one: '1 second',
    );
    return '$_temp0';
  }

  @override
  String crackTimeMinutes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count minutes',
      one: '1 minute',
    );
    return '$_temp0';
  }

  @override
  String crackTimeHours(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count hours',
      one: '1 hour',
    );
    return '$_temp0';
  }

  @override
  String crackTimeDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count days',
      one: '1 day',
    );
    return '$_temp0';
  }

  @override
  String crackTimeMonths(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count months',
      one: '1 month',
    );
    return '$_temp0';
  }

  @override
  String crackTimeYears(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count years',
      one: '1 year',
    );
    return '$_temp0';
  }

  @override
  String crackTimeCenturies(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count centuries',
      one: '1 century',
    );
    return '$_temp0';
  }

  @override
  String get crackTimeMillionsOfYears => 'millions of years';

  @override
  String get unlockPreviousPasswordNeeded =>
      'This device has changes that haven\'t been synced yet. To keep them, also enter the previous password.';

  @override
  String get unlockPreviousPasswordWrong =>
      'The previous password is not correct';

  @override
  String get unlockWelcomeBack => 'Welcome back!';

  @override
  String get unlockPrompt => 'Enter your password to open your vault';

  @override
  String unlockPasswordChangedElsewhere(Object method) {
    return 'The master password was changed on another device. Enter the new one to get in. Until then, $method can\'t be used.';
  }

  @override
  String unlockPeriodicReminder(Object method) {
    return 'For security, Lockspire asks for your master password every so often even if you use $method, so you don\'t forget it. Afterwards it works as usual again.';
  }

  @override
  String get unlockPreviousPassword => 'Previous password';

  @override
  String get unlockPreviousPasswordRequired => 'Enter the previous password';

  @override
  String get unlockUnlocking =>
      'Unlocking… this may take a few seconds (Argon2id key derivation)';

  @override
  String get unlockButton => 'Unlock';

  @override
  String get unlockEnterNewPassword => 'Enter the new password';

  @override
  String get unlockNoNewPassword => 'I don\'t have the new password';

  @override
  String unlockUseBiometric(Object method) {
    return 'Use $method';
  }

  @override
  String get createVaultTitle => 'Create vault';

  @override
  String get createVaultHeading => 'Create your vault';

  @override
  String get createVaultIntro =>
      'Choose a master password. It is never sent or stored: if you forget it, there is no way to recover it.';

  @override
  String createVaultMinLength(int count) {
    return 'At least $count characters';
  }

  @override
  String get createVaultPasswordRequired => 'Enter a password';

  @override
  String get createVaultConfirm => 'Confirm password';

  @override
  String get createVaultMismatch => 'Doesn\'t match the password above';

  @override
  String get createVaultCreating =>
      'Creating vault… this may take a few seconds (Argon2id key derivation)';

  @override
  String createVaultFailed(Object error) {
    return 'Could not create the vault: $error';
  }

  @override
  String get createVaultRestoreLink =>
      'Already have a vault? Restore it from the cloud';

  @override
  String get changePwDone =>
      'Master password changed. Your other devices will ask for it the next time they sync.';

  @override
  String get changePwCurrentWrong => 'The current password is not correct';

  @override
  String get changePwConflict =>
      'The vault changed while saving. The cloud already has the new password: sync, and when you\'re asked, enter it.';

  @override
  String changePwFailed(Object error) {
    return 'The password could not be changed, so it\'s still the same. $error';
  }

  @override
  String get changePwTitle => 'Change master password';

  @override
  String get changePwIntro =>
      'If you use sync, it syncs first and the new vault is uploaded to the cloud: a connection is needed. Old copies someone already has still open with the previous password.';

  @override
  String get changePwCurrent => 'Current password';

  @override
  String get changePwCurrentRequired => 'Enter your current password';

  @override
  String changePwNewHelper(int count) {
    return 'At least $count characters, hard to guess';
  }

  @override
  String get changePwMustDiffer => 'It must be different from the current one';

  @override
  String get changePwConfirmNew => 'Confirm new password';

  @override
  String get changePwMismatch => 'Doesn\'t match the new password';

  @override
  String get changePwShowPasswords => 'Show passwords';

  @override
  String get changePwButton => 'Change password';

  @override
  String get commonRetry => 'Retry';

  @override
  String get strengthWeak => 'Weak';

  @override
  String get strengthFair => 'Fair';

  @override
  String get strengthStrong => 'Strong';

  @override
  String strengthLabel(Object level, Object time) {
    return '$level, estimated time to crack it: $time';
  }

  @override
  String get deleteEntriesBody =>
      'They are removed from the vault on this device, and on the others when they sync.';

  @override
  String get commonDelete => 'Delete';

  @override
  String biometricOptInTitle(Object methodName) {
    return 'Turn on unlocking with $methodName?';
  }

  @override
  String biometricOptInBody(Object methodName) {
    return 'Instead of typing the master password every time, you\'ll be able to unlock the vault with $methodName. You can change this later in \"Security\".';
  }

  @override
  String get commonNotNow => 'Not now';

  @override
  String get commonTurnOn => 'Turn on';

  @override
  String get entryTypePassword => 'Password';

  @override
  String get entryTypeCard => 'Card';

  @override
  String get entryTypeDocument => 'Document';

  @override
  String get selectionCancel => 'Cancel selection';

  @override
  String selectionCount(int count) {
    return '$count selected';
  }

  @override
  String get selectionClear => 'Clear selection';

  @override
  String get selectionAll => 'Select all';

  @override
  String get selectionDelete => 'Delete selected';

  @override
  String get selectionStart => 'Select';

  @override
  String get commonLock => 'Lock';

  @override
  String get vaultSearchHint => 'Search by title, username or site';

  @override
  String get commonAdd => 'Add';

  @override
  String get autofillSettingsOpenFailed => 'Could not open the settings.';

  @override
  String get securityTitle => 'Security';

  @override
  String get securityChangePwHint =>
      'Do it if you think someone may have learned it.';

  @override
  String securityUnlockWith(Object method) {
    return 'Unlock with $method';
  }

  @override
  String securityUnlockWithHint(Object method) {
    return 'Use $method instead of typing the master password every time.';
  }

  @override
  String get autofillSettingsTitle => 'Autofill';

  @override
  String get autofillSettingsHint =>
      'Turn on Lockspire as the autofill service so it shows up as an option when you sign in to other apps, including sign-ins inside an embedded browser (e.g. WebView).';

  @override
  String get autofillSettingsButton => 'Set as autofill service';

  @override
  String securityBiometricNotSetUp(Object method) {
    return '$method is not set up on this device.';
  }

  @override
  String securityBiometricSetUpHint(Object method) {
    return 'Set up $method in the system settings to turn it on here.';
  }

  @override
  String get securityBiometricUnavailable => 'Not available on this device.';

  @override
  String get securityReminderTitle => 'Ask for the master password every';

  @override
  String securityReminderHint(Object method) {
    return 'Even if you use $method, after this time Lockspire asks for the password once, so you don\'t forget it. If you forget it, the vault can\'t be recovered.';
  }

  @override
  String get securityAutoLock => 'Auto-lock';

  @override
  String get securityAutoLock15Warning =>
      'More convenient, but the vault stays open longer if you step away from the device.';

  @override
  String get siteIconsTitle => 'Site icons';

  @override
  String get siteIconsHint =>
      'Downloads each saved site\'s icon directly from the site, without third-party services, and stores it encrypted in your vault. Each site sees a visit from your connection. When off, the initial is shown.';

  @override
  String get siteIconsFallback => 'Fill in the missing ones with DuckDuckGo';

  @override
  String get siteIconsFallbackHint =>
      'For sites that don\'t offer an icon, it asks DuckDuckGo. DuckDuckGo only receives those domains, never your usernames or passwords.';

  @override
  String get siteIconsRetry => 'Look again for the missing ones';

  @override
  String get vaultNoResults => 'No results found';

  @override
  String get vaultEmpty => 'You haven\'t saved any passwords yet';

  @override
  String get vaultEmptyHint => 'Tap the \"+\" button to add the first one';

  @override
  String get generatorRandom => 'Random';

  @override
  String get generatorMemorable => 'Easy to remember';

  @override
  String generatorLength(int count) {
    return '$count characters';
  }

  @override
  String deleteEntriesTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Delete $count entries?',
      one: 'Delete 1 entry?',
    );
    return '$_temp0';
  }

  @override
  String deleteEntriesDone(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count entries deleted',
      one: '1 entry deleted',
    );
    return '$_temp0';
  }

  @override
  String commonDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count days',
      one: '1 day',
    );
    return '$_temp0';
  }

  @override
  String commonMinutesShort(int count) {
    return '$count min';
  }

  @override
  String get securityAutoLockHintAndroid =>
      'The vault locks itself when this much time passes without using Lockspire. It also locks when you leave the app.';

  @override
  String get securityAutoLockHintDesktop =>
      'The vault locks itself when this much time passes without using Lockspire. It also locks when you lock your session or put the computer to sleep.';

  @override
  String entryConflict(Object error) {
    return '$error Check the data and try saving again.';
  }

  @override
  String entrySaveFailed(Object error) {
    return 'Could not save: $error';
  }

  @override
  String get entryDeleteTitle => 'Delete this entry?';

  @override
  String entryDeleteBody(Object title) {
    return '\"$title\" will be removed from the vault.';
  }

  @override
  String entryCopied(Object label, int seconds) {
    return 'Copied: $label. Cleared in $seconds s or when locked';
  }

  @override
  String get fieldUsername => 'Username';

  @override
  String get fieldPassword => 'Password';

  @override
  String get entryGeneratePassword => 'Generate password';

  @override
  String get fieldTitle => 'Title';

  @override
  String get entryTitleRequired => 'Enter a title';

  @override
  String get entryWebsites => 'Websites';

  @override
  String get fieldWebsite => 'Website';

  @override
  String get entryAddWebsite => 'Add website';

  @override
  String get entryAndroidApps => 'Android apps';

  @override
  String get entryAppPackage => 'App (package)';

  @override
  String get entryAddApp => 'Add app';

  @override
  String get entryOtherFields => 'Other fields';

  @override
  String get entryAndroidApp => 'Android app';

  @override
  String get entryField => 'Field';

  @override
  String get fieldNotes => 'Notes';

  @override
  String get entrySavedEncrypted =>
      'It is stored encrypted along with the rest of your vault.';

  @override
  String fieldCopy(Object field) {
    return 'Copy $field';
  }

  @override
  String get commonShow => 'Show';

  @override
  String get commonHide => 'Hide';

  @override
  String get commonRemove => 'Remove';

  @override
  String get customFieldRemove => 'Remove field';

  @override
  String get customFieldAdd => 'Add field';

  @override
  String get customFieldNameRequired => 'Enter a name';

  @override
  String get customFieldNameTaken => 'There is already a field with that name';

  @override
  String get customFieldNew => 'New field';

  @override
  String get customFieldName => 'Field name';

  @override
  String get customFieldNameHint => 'For example: Secret question';

  @override
  String get customFieldHidden => 'Hide the value';

  @override
  String get customFieldHiddenHint => 'For keys, PINs and other sensitive data';

  @override
  String get fieldCardNumber => 'Card number';

  @override
  String get fieldCardHolder => 'Cardholder';

  @override
  String get fieldExpiry => 'Expires';

  @override
  String get fieldCardExpiryHint => 'MM/YY';

  @override
  String get fieldCvv => 'CVV';

  @override
  String get fieldPin => 'PIN';

  @override
  String get fieldDocNumber => 'Number';

  @override
  String get fieldDocName => 'Name';

  @override
  String get fieldBirthDate => 'Date of birth';

  @override
  String get fieldIssued => 'Issued';

  @override
  String get fieldDateHint => 'DD/MM/YYYY';

  @override
  String fieldWebsiteN(Object n) {
    return 'Website $n';
  }

  @override
  String fieldAppN(Object n) {
    return 'App $n';
  }

  @override
  String get fieldGenerationMode => 'Generation mode';

  @override
  String get fieldGenerationParam => 'Generation setting';

  @override
  String get historyTitle => 'Previous values';

  @override
  String get historyHint =>
      'What these fields had before: when you edited them, updated them from the browser, imported them, or when a change on another device was resolved automatically.';

  @override
  String get historyCopy => 'Copy the previous value';

  @override
  String entryNewTitle(String type) {
    String _temp0 = intl.Intl.selectLogic(type, {
      'card': 'New card',
      'document': 'New document',
      'note': 'New note',
      'passkey': 'New passkey',
      'other': 'New password',
    });
    return '$_temp0';
  }

  @override
  String entryEditTitle(String type) {
    String _temp0 = intl.Intl.selectLogic(type, {
      'card': 'Edit card',
      'document': 'Edit document',
      'note': 'Edit note',
      'passkey': 'Edit passkey',
      'other': 'Edit password',
    });
    return '$_temp0';
  }

  @override
  String importReadFailed(Object error) {
    return 'Could not read the file: $error';
  }

  @override
  String importConflict(Object error) {
    return '$error Try importing again.';
  }

  @override
  String importFailed(Object error) {
    return 'Could not import: $error';
  }

  @override
  String get importDoneTitle => 'Import complete';

  @override
  String importDoneUnencrypted(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count entries were imported',
      one: '1 entry was imported',
    );
    return '$_temp0. For your security: the file you chose is not encrypted. Delete it from where you saved it (and from the trash): Lockspire can\'t delete it for you.';
  }

  @override
  String importDoneBackup(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count entries were imported',
      one: '1 entry was imported',
    );
    return '$_temp0 from the backup.';
  }

  @override
  String get commonGotIt => 'Got it';

  @override
  String get importTitle => 'Import';

  @override
  String get importIntro =>
      'Choose the file you exported from your other manager, or a Lockspire backup. It is read directly in memory without saving any copy, and entries you already have are never duplicated.';

  @override
  String get importBitwardenDetail => 'Unencrypted CSV or JSON';

  @override
  String get importOthersSource =>
      'Chrome, Edge, Firefox, KeePassXC and others';

  @override
  String get importLockspireBackup => 'Lockspire backup';

  @override
  String get importLockspireBackupDetail => '.lockspire, with its password';

  @override
  String get importChooseFile => 'Choose file';

  @override
  String get importNothingNew => 'No new entries';

  @override
  String importWillImport(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count entries will be imported',
      one: '1 entry will be imported',
    );
    return '$_temp0';
  }

  @override
  String importSkipped(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count were already in your vault and are skipped',
      one: '1 was already in your vault and is skipped',
    );
    return '$_temp0';
  }

  @override
  String get importBackupPassword => 'Backup password';

  @override
  String get importBackupPasswordHint =>
      'Enter the master password the vault had when this backup was made.';

  @override
  String get commonOpen => 'Open';

  @override
  String get exportUnencryptedTitle => 'The file will not be encrypted';

  @override
  String get exportUnencryptedConfirm => 'I understand, export';

  @override
  String get exportWrongPassword => 'The master password is not correct';

  @override
  String get exportSaveDialogTitle => 'Save export';

  @override
  String exportFailed(Object error) {
    return 'Could not export: $error';
  }

  @override
  String get exportDoneTitle => 'Export ready';

  @override
  String get exportDoneBackup =>
      'The encrypted backup was saved. Opening it requires the current master password; if you change it later, this backup still asks for today\'s.';

  @override
  String exportDoneFile(Object format) {
    return 'The $format was saved.';
  }

  @override
  String exportSkipped(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count cards or documents were not included',
      one: '1 card or document was not included',
    );
    return '$_temp0: this format only carries passwords.';
  }

  @override
  String get exportDeleteReminder =>
      'Remember to delete it, also from the trash, as soon as you import it into the other manager.';

  @override
  String get exportTitle => 'Export';

  @override
  String get exportFormat => 'Format';

  @override
  String get exportBackupLabel => 'Lockspire backup (encrypted)';

  @override
  String get exportBackupHint =>
      'All your content, encrypted with your master password. To keep as a backup or restore into another Lockspire.';

  @override
  String get exportUnencryptedNote =>
      'This format is not encrypted. Only use it to move your data to another manager.';

  @override
  String get exportPasswordAlwaysAsked =>
      'Exporting always asks for the password.';

  @override
  String importCountPasswords(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count passwords',
      one: '1 password',
    );
    return '$_temp0';
  }

  @override
  String importCountCards(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count cards',
      one: '1 card',
    );
    return '$_temp0';
  }

  @override
  String importCountDocuments(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count documents',
      one: '1 document',
    );
    return '$_temp0';
  }

  @override
  String commonListAnd(Object first, Object last) {
    return '$first and $last';
  }

  @override
  String exportUnencryptedBodyPasswords(Object format) {
    return 'Anyone who opens the $format will see all your passwords. Keep it only as long as needed to import it into the other manager, then delete it, also from the trash. Don\'t upload it to the cloud or send it by email or chat.';
  }

  @override
  String exportUnencryptedBodyAll(Object format) {
    return 'Anyone who opens the $format will see all your passwords, cards and documents. Keep it only as long as needed to import it into the other manager, then delete it, also from the trash. Don\'t upload it to the cloud or send it by email or chat.';
  }

  @override
  String get exportBitwardenCsv => 'Bitwarden CSV';

  @override
  String get exportBitwardenCsvHint =>
      'Unencrypted. Accepted by Bitwarden, Proton Pass, 1Password, KeePassXC and others. Cards and documents go as notes.';

  @override
  String get exportBitwardenJson => 'Bitwarden JSON';

  @override
  String get exportBitwardenJsonHint =>
      'Unencrypted. Includes cards and documents. Read by Bitwarden and other managers that import from Bitwarden.';

  @override
  String get exportChromeCsv => 'Chrome CSV';

  @override
  String get exportChromeCsvHint =>
      'Unencrypted. The simplest format: imported by Chrome, Edge, Firefox and Google Password Manager. Passwords only.';

  @override
  String get browserRegistered =>
      'Done. Restart the browser if it was already open.';

  @override
  String get browserUnregistered =>
      'Lockspire is no longer connected to browsers.';

  @override
  String get browserRegisteredSystemWide =>
      'Done for the whole computer. Restart the browser if it was already open.';

  @override
  String get browserUnregisteredSystemWide =>
      'The registration for the whole computer was removed.';

  @override
  String get browserTitle => 'Browser';

  @override
  String get browserIntro =>
      'With the Lockspire extension for Chrome or Edge you can fill in usernames and passwords on websites. The extension asks this app for the credentials; the vault never leaves here and, if it\'s locked, the extension asks you to unlock it first.';

  @override
  String browserConnectedWith(Object browsers) {
    return 'Connected with $browsers';
  }

  @override
  String get browserNotConnected => 'Not connected with any browser';

  @override
  String get browserHostMissing =>
      'The \"lockspire-native-host\" component is missing next to the app. See native-host/README.md.';

  @override
  String browserOtherCopy(String browsers) {
    return 'Another copy of Lockspire (for example, an old version) is registered in $browsers, and the browser uses that one. Press \"Connect with Chrome/Edge\" so it uses this one.';
  }

  @override
  String get browserOtherCopySystemWide =>
      'The computer-wide registration points to another copy of Lockspire, and the browser may be using it instead of this one. Register it again or remove it.';

  @override
  String get browserReconnect => 'Reconnect';

  @override
  String get browserConnect => 'Connect with Chrome/Edge';

  @override
  String get browserSystemWide => 'For the whole computer';

  @override
  String get browserSystemWideHint =>
      'If the extension still says it\'s not connected, your organization may be blocking per-user connections (Chrome\'s \"NativeMessagingUserLevelHosts\" policy, visible at chrome://policy). In that case, register Lockspire for the whole computer: Windows will ask for administrator permission.';

  @override
  String get browserSystemWideOn => 'Registered for the whole computer';

  @override
  String get browserSystemWideOff => 'Not registered for the whole computer';

  @override
  String get browserReregister => 'Register again';

  @override
  String get browserRegisterSystemWide => 'Register for the whole computer';

  @override
  String get browserRemoveRegistration => 'Remove registration';

  @override
  String get browserInstallExtension => 'Install the extension';

  @override
  String get browserInstallExtensionHint =>
      'Until it\'s published in the Chrome Web Store: open chrome://extensions (or edge://extensions), turn on \"Developer mode\", choose \"Load unpacked\" and select the project\'s extension/dist folder.';

  @override
  String get bridgeRunning => 'Lockspire is listening to the extension.';

  @override
  String get bridgeAnotherInstance =>
      'Another Lockspire instance is already serving the extension.';

  @override
  String get bridgeUnavailable =>
      'Could not open the channel with the extension on this computer.';

  @override
  String get bridgeUnsupported =>
      'The browser extension only works on desktop.';

  @override
  String get commonStarting => 'Starting…';

  @override
  String get linkTitle => 'Link this site?';

  @override
  String linkBody(Object title) {
    return 'The extension wants to use \"$title\" on:';
  }

  @override
  String get linkNoUrl => 'The entry didn\'t have any URL.';

  @override
  String linkReplacesUrl(Object url) {
    return 'Replaces the current URL: $url';
  }

  @override
  String get linkPhishingWarning =>
      'Check that the address is the real one: if it\'s a fake site imitating the original, you\'d be giving it this password.';

  @override
  String get linkConfirm => 'Link';

  @override
  String get linkEntryGone => 'The entry no longer exists.';

  @override
  String linkDone(Object title, Object host) {
    return '\"$title\" linked to $host. Open the extension again to fill in.';
  }

  @override
  String get linkSaveFailed => 'Could not save the link.';

  @override
  String browserLoginSaved(String site) {
    return 'Saved the password for $site.';
  }

  @override
  String browserLoginSaveFailed(String site) {
    return 'Could not save the password for $site.';
  }

  @override
  String get browserNeverSaveTitle =>
      'Sites where saving passwords isn\'t offered';

  @override
  String browserNeverSaveRemove(String site) {
    return 'Offer again on $site';
  }

  @override
  String get navVault => 'Vault';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get settingsAppearanceHint => 'Language, theme and site icons';

  @override
  String get settingsImportHint =>
      'From SafeInCloud, Bitwarden, Chrome, KeePassXC or a Lockspire backup';

  @override
  String get settingsExportHint =>
      'Encrypted backup, or CSV/JSON for another manager';

  @override
  String get settingsBrowserHint => 'Connect with the Chrome/Edge extension';

  @override
  String get aboutTitle => 'About';

  @override
  String get settingsAboutHint => 'Version, license and source code';

  @override
  String get settingsGeneral => 'General';

  @override
  String get settingsIntegrations => 'Integrations';

  @override
  String get settingsData => 'Data';

  @override
  String get settingsAutofillHint => 'Fill in your passwords in other apps';

  @override
  String get securityMasterPasswordSection => 'Master password';

  @override
  String get securityUnlockSection => 'Unlock';

  @override
  String get trayOpen => 'Open Lockspire';

  @override
  String get trayQuit => 'Quit';

  @override
  String get trayStillOpenTitle => 'Lockspire is still open';

  @override
  String get trayStillOpenBody =>
      'When you close the window, Lockspire stays in the system tray so the browser extension can autofill. The vault locks itself after the idle time you choose in Security, when you lock your session or when the computer goes to sleep.\n\nTo close it completely, use \"Quit\" on the tray icon.';

  @override
  String aboutOpenFailed(Object url) {
    return 'Could not open $url';
  }

  @override
  String aboutVersion(Object version, Object build) {
    return 'Version $version ($build)';
  }

  @override
  String get aboutTagline =>
      'A free, local password manager. Your vault is encrypted on your device and only syncs with the cloud you choose. No ads, no analytics and no servers of our own.';

  @override
  String get aboutDevelopedBy => 'Developed by';

  @override
  String get aboutAuthorLine =>
      'Systems engineer and backend developer, trained in secure software development (CSSLP, OWASP Top 10).';

  @override
  String get aboutSourceCode => 'Source code';

  @override
  String get aboutLicense => 'License';

  @override
  String get aboutLicenseName =>
      'GNU Affero General Public License v3 or later';

  @override
  String get aboutPrivacyPolicy => 'Privacy policy';

  @override
  String get aboutThirdParty => 'Third-party licenses';

  @override
  String get aboutThirdPartyHint => 'Open source components Lockspire uses';

  @override
  String aboutLegalese(Object author) {
    return 'Copyright (C) 2026 $author. Distributed under the GNU AGPL v3 or later.';
  }

  @override
  String get aboutDonateTitle => 'Buy me a coffee';

  @override
  String get aboutDonateBody =>
      'Lockspire is free, ad-free and open source. If you find it useful, you can support its development with a donation.';

  @override
  String get aboutDonateCoffee => 'A coffee';

  @override
  String get aboutDonateCoffeeAndCake => 'Coffee and cake';

  @override
  String get aboutDonateLunch => 'A lunch';

  @override
  String get aboutDonateThanks => 'Thank you for your support!';

  @override
  String get aboutDonatePending =>
      'Your payment is pending. Thank you for your support!';

  @override
  String get aboutDonateFailed =>
      'The donation could not be completed. Please try again later.';

  @override
  String get autofillWrongSiteTitle => 'Is this the right site?';

  @override
  String autofillWrongSiteBody(
    Object title,
    Object entrySite,
    Object pageHost,
  ) {
    return '\"$title\" belongs to $entrySite, but the page asking for it is $pageHost.\n\nIf you weren\'t expecting this site, it may be a fake page trying to steal your password (phishing).';
  }

  @override
  String get autofillFillAnyway => 'Fill anyway';

  @override
  String get autofillNoSiteTitle => 'This entry has no site';

  @override
  String autofillNoSiteBody(Object title, Object host) {
    return '\"$title\" has no saved site, so Lockspire can\'t check that $host is the right one.\n\nIf you remember it, next time it will fill in by itself, and only on this site.';
  }

  @override
  String get autofillJustOnce => 'Just this once';

  @override
  String get autofillFillAndRemember => 'Fill and remember';

  @override
  String get autofillSearchHint => 'Search by title';

  @override
  String get autofillEmpty =>
      'You haven\'t saved any passwords in Lockspire yet.';

  @override
  String get autofillNoResults => 'No results found.';

  @override
  String get autofillMatchesSite => 'Matches the site';

  @override
  String get autofillSavePrompt => 'Save this credential in Lockspire?';

  @override
  String get autofillNoThanks => 'No, thanks';

  @override
  String get autofillBadRequest =>
      'The autofill request could not be understood.';

  @override
  String get autofillNoVault =>
      'You haven\'t created a vault in Lockspire yet.';

  @override
  String get commonClose => 'Close';

  @override
  String get autofillAndroidApp => 'Android app';

  @override
  String get autofillUnknownApp => 'Unknown app';

  @override
  String autofillInBrowser(Object browser) {
    return 'in $browser';
  }

  @override
  String get autofillInUnknownApp => 'in an unknown app';

  @override
  String autofillInsideApp(Object package) {
    return 'inside the app $package';
  }

  @override
  String get biometricPromptReason =>
      'Verify your identity to unlock Lockspire';

  @override
  String get errorProfileNameEmpty => 'Enter a name for the profile.';

  @override
  String get errorProfileNameTooLong =>
      'The name can have up to 30 characters.';

  @override
  String get errorProfileNameTaken =>
      'There\'s already a profile with that name.';

  @override
  String get errorProfileMainNotRemovable =>
      'The main profile can\'t be deleted.';

  @override
  String get errorProfilesInUse =>
      'To turn profiles off, delete the others first: only one can remain.';

  @override
  String get profilesTitle => 'Profiles';

  @override
  String get profilesSubtitle => 'Several vaults on this device';

  @override
  String get profilesIntro =>
      'Each profile has its own vault, with its own master password, and its own settings: cloud, fingerprint, lock, theme and language. Use them if someone else uses Lockspire on this device.';

  @override
  String get profilesEnable => 'Use several profiles';

  @override
  String get profilesEnableHint =>
      'They\'re off by default because sharing a phone is unusual.';

  @override
  String get profilesMainName => 'Main';

  @override
  String get profilesInUse => 'In use';

  @override
  String get profilesAdd => 'Add profile';

  @override
  String get profilesAddTitle => 'New profile';

  @override
  String get profilesAddBody =>
      'It opens empty: there you can create your vault or restore it from the cloud.';

  @override
  String get profilesNameLabel => 'Name';

  @override
  String get profilesRename => 'Rename';

  @override
  String get profilesRenameTitle => 'Profile name';

  @override
  String get profilesDelete => 'Delete this profile';

  @override
  String profilesDeleteTitle(String name) {
    return 'Delete the profile $name?';
  }

  @override
  String get profilesDeleteBody =>
      'This profile\'s vault and settings are deleted from this device. Anything synced to the cloud is not touched. This can\'t be undone.';

  @override
  String get profilesSwitch => 'Open';

  @override
  String get profilesPickerLabel => 'Profile';

  @override
  String get profilesOpening => 'Opening the profile…';
}
