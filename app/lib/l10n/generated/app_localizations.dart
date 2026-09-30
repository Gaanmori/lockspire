import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_es.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('es'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In es, this message translates to:
  /// **'Lockspire'**
  String get appTitle;

  /// No description provided for @appearanceTitle.
  ///
  /// In es, this message translates to:
  /// **'Apariencia'**
  String get appearanceTitle;

  /// No description provided for @appearanceMode.
  ///
  /// In es, this message translates to:
  /// **'Modo'**
  String get appearanceMode;

  /// No description provided for @appearanceModeSystem.
  ///
  /// In es, this message translates to:
  /// **'Sistema'**
  String get appearanceModeSystem;

  /// No description provided for @appearanceModeLight.
  ///
  /// In es, this message translates to:
  /// **'Claro'**
  String get appearanceModeLight;

  /// No description provided for @appearanceModeDark.
  ///
  /// In es, this message translates to:
  /// **'Oscuro'**
  String get appearanceModeDark;

  /// No description provided for @appearanceModeSystemHint.
  ///
  /// In es, this message translates to:
  /// **'Cambia sola entre claro y oscuro según su sistema.'**
  String get appearanceModeSystemHint;

  /// No description provided for @appearanceTheme.
  ///
  /// In es, this message translates to:
  /// **'Tema'**
  String get appearanceTheme;

  /// No description provided for @appearanceLauncherIconNote.
  ///
  /// In es, this message translates to:
  /// **'El ícono de Lockspire en el teléfono también cambia al tema elegido, en unos segundos. Algunos lanzadores quitan el acceso directo de la pantalla de inicio al cambiarlo: vuelva a agregarlo desde la lista de apps.'**
  String get appearanceLauncherIconNote;

  /// No description provided for @themeSystemColors.
  ///
  /// In es, this message translates to:
  /// **'Colores del sistema'**
  String get themeSystemColors;

  /// No description provided for @themeGroupLockspire.
  ///
  /// In es, this message translates to:
  /// **'Lockspire'**
  String get themeGroupLockspire;

  /// No description provided for @themeGroupAutomatic.
  ///
  /// In es, this message translates to:
  /// **'Automático'**
  String get themeGroupAutomatic;

  /// No description provided for @themeGroupOperatingSystems.
  ///
  /// In es, this message translates to:
  /// **'Inspirados en sistemas operativos'**
  String get themeGroupOperatingSystems;

  /// No description provided for @themeGrafitoHint.
  ///
  /// In es, this message translates to:
  /// **'Sobrio, combina con todo. El predeterminado.'**
  String get themeGrafitoHint;

  /// No description provided for @themeCustom.
  ///
  /// In es, this message translates to:
  /// **'Personalizado'**
  String get themeCustom;

  /// No description provided for @themeCustomHint.
  ///
  /// In es, this message translates to:
  /// **'Elija cualquier color: Lockspire arma la paleta clara y oscura.'**
  String get themeCustomHint;

  /// No description provided for @themeCustomHex.
  ///
  /// In es, this message translates to:
  /// **'Color en hexadecimal'**
  String get themeCustomHex;

  /// No description provided for @themeCustomApply.
  ///
  /// In es, this message translates to:
  /// **'Usar este color'**
  String get themeCustomApply;

  /// No description provided for @themeCustomInvalid.
  ///
  /// In es, this message translates to:
  /// **'Escriba un color como #6750A4.'**
  String get themeCustomInvalid;

  /// No description provided for @themeSystemUnavailable.
  ///
  /// In es, this message translates to:
  /// **'No disponible en este equipo: se usa Grafito.'**
  String get themeSystemUnavailable;

  /// No description provided for @themeSystemAndroid.
  ///
  /// In es, this message translates to:
  /// **'Material You: colores de su fondo de pantalla.'**
  String get themeSystemAndroid;

  /// No description provided for @themeSystemDesktop.
  ///
  /// In es, this message translates to:
  /// **'Color de acento del sistema.'**
  String get themeSystemDesktop;

  /// No description provided for @appearanceThemeSemantics.
  ///
  /// In es, this message translates to:
  /// **'Tema {title}'**
  String appearanceThemeSemantics(Object title);

  /// No description provided for @appearanceInUse.
  ///
  /// In es, this message translates to:
  /// **'En uso'**
  String get appearanceInUse;

  /// No description provided for @appearanceLanguage.
  ///
  /// In es, this message translates to:
  /// **'Idioma'**
  String get appearanceLanguage;

  /// No description provided for @syncConnectFailed.
  ///
  /// In es, this message translates to:
  /// **'No se pudo conectar con {provider}: {error}'**
  String syncConnectFailed(Object provider, Object error);

  /// No description provided for @syncMoveTitle.
  ///
  /// In es, this message translates to:
  /// **'¿Mudar la bóveda a {target}?'**
  String syncMoveTitle(Object target);

  /// No description provided for @syncMoveBody.
  ///
  /// In es, this message translates to:
  /// **'Su bóveda se sincroniza con {home}. Si continúa, pasa a sincronizarse con {target} y se deja un aviso en {home}.\n\nSus otros dispositivos van a recibir ese aviso la próxima vez que sincronicen, y tendrán que conectar {target} para seguir. No se pierde nada: lo que esté en {target} se fusiona con esta bóveda.'**
  String syncMoveBody(Object home, Object target);

  /// No description provided for @commonCancel.
  ///
  /// In es, this message translates to:
  /// **'Cancelar'**
  String get commonCancel;

  /// No description provided for @syncMoveConfirm.
  ///
  /// In es, this message translates to:
  /// **'Mudar'**
  String get syncMoveConfirm;

  /// No description provided for @syncReplaceRemoteTitle.
  ///
  /// In es, this message translates to:
  /// **'¿Reemplazar la copia de la nube?'**
  String get syncReplaceRemoteTitle;

  /// No description provided for @syncReplaceRemoteBody.
  ///
  /// In es, this message translates to:
  /// **'La nube tiene una versión más vieja que la de este dispositivo. Si restauró una copia antigua a propósito, puede reemplazarla con la de este dispositivo: no pierde nada que tenga aquí.\n\nSi no fue usted, alguien pudo haber accedido a su cuenta de la nube: cambie esa contraseña antes de seguir.'**
  String get syncReplaceRemoteBody;

  /// No description provided for @syncReplaceConfirm.
  ///
  /// In es, this message translates to:
  /// **'Reemplazar'**
  String get syncReplaceConfirm;

  /// No description provided for @syncResultUploaded.
  ///
  /// In es, this message translates to:
  /// **'Se subió la bóveda al servidor.'**
  String get syncResultUploaded;

  /// No description provided for @syncResultDownloaded.
  ///
  /// In es, this message translates to:
  /// **'Se bajó la bóveda del servidor.'**
  String get syncResultDownloaded;

  /// No description provided for @syncResultUpToDate.
  ///
  /// In es, this message translates to:
  /// **'Ya estaba al día — nada que hacer.'**
  String get syncResultUpToDate;

  /// No description provided for @syncResultMergedFields.
  ///
  /// In es, this message translates to:
  /// **'Se fusionaron los cambios: {fieldConflictsResolved, plural, =1{1 campo se resolvió automáticamente} other{{fieldConflictsResolved} campos se resolvieron automáticamente}} (puede ver el valor anterior en el historial de esa entrada).'**
  String syncResultMergedFields(int fieldConflictsResolved);

  /// No description provided for @syncResultMergedEntries.
  ///
  /// In es, this message translates to:
  /// **'Se fusionaron los cambios: {autoResolvedCount, plural, =1{1 entrada resuelta automáticamente} other{{autoResolvedCount} entradas resueltas automáticamente}}.'**
  String syncResultMergedEntries(int autoResolvedCount);

  /// No description provided for @syncResultMerged.
  ///
  /// In es, this message translates to:
  /// **'Se fusionaron los cambios.'**
  String get syncResultMerged;

  /// No description provided for @syncResultMoved.
  ///
  /// In es, this message translates to:
  /// **'Su bóveda se mudó a {provider}. Conéctela arriba para seguir sincronizando.'**
  String syncResultMoved(Object provider);

  /// No description provided for @syncWebdavUrl.
  ///
  /// In es, this message translates to:
  /// **'URL del servidor WebDAV'**
  String get syncWebdavUrl;

  /// No description provided for @syncWebdavUrlRequired.
  ///
  /// In es, this message translates to:
  /// **'Ingrese la URL del servidor'**
  String get syncWebdavUrlRequired;

  /// No description provided for @syncWebdavHttpsRequired.
  ///
  /// In es, this message translates to:
  /// **'Use https://: con http:// su usuario y contraseña del servidor viajarían sin cifrar.'**
  String get syncWebdavHttpsRequired;

  /// No description provided for @syncWebdavUrlInvalid.
  ///
  /// In es, this message translates to:
  /// **'Ingrese una URL completa, p. ej. https://servidor/dav'**
  String get syncWebdavUrlInvalid;

  /// No description provided for @syncWebdavUser.
  ///
  /// In es, this message translates to:
  /// **'Usuario'**
  String get syncWebdavUser;

  /// No description provided for @syncWebdavUserRequired.
  ///
  /// In es, this message translates to:
  /// **'Ingrese el usuario'**
  String get syncWebdavUserRequired;

  /// No description provided for @syncWebdavPassword.
  ///
  /// In es, this message translates to:
  /// **'Contraseña'**
  String get syncWebdavPassword;

  /// No description provided for @syncWebdavPasswordUnchanged.
  ///
  /// In es, this message translates to:
  /// **'(sin cambios si se deja vacío)'**
  String get syncWebdavPasswordUnchanged;

  /// No description provided for @syncWebdavPasswordRequired.
  ///
  /// In es, this message translates to:
  /// **'Ingrese la contraseña'**
  String get syncWebdavPasswordRequired;

  /// No description provided for @commonSave.
  ///
  /// In es, this message translates to:
  /// **'Guardar'**
  String get commonSave;

  /// No description provided for @syncTitle.
  ///
  /// In es, this message translates to:
  /// **'Sincronización'**
  String get syncTitle;

  /// No description provided for @syncGoogleScopeNote.
  ///
  /// In es, this message translates to:
  /// **'Lockspire solo accede a su propia carpeta oculta de datos en su Drive: no ve el resto de sus archivos.'**
  String get syncGoogleScopeNote;

  /// No description provided for @syncConnectGoogle.
  ///
  /// In es, this message translates to:
  /// **'Conectar con Google'**
  String get syncConnectGoogle;

  /// No description provided for @syncOneDriveScopeNote.
  ///
  /// In es, this message translates to:
  /// **'Lockspire solo accede a su propia carpeta especial de app en su OneDrive: no ve el resto de sus archivos.'**
  String get syncOneDriveScopeNote;

  /// No description provided for @syncConnectOneDrive.
  ///
  /// In es, this message translates to:
  /// **'Conectar con OneDrive'**
  String get syncConnectOneDrive;

  /// No description provided for @commonErrorDetail.
  ///
  /// In es, this message translates to:
  /// **'Ocurrió un error: {error}'**
  String commonErrorDetail(Object error);

  /// No description provided for @syncNow.
  ///
  /// In es, this message translates to:
  /// **'Sincronizar ahora'**
  String get syncNow;

  /// No description provided for @syncFailed.
  ///
  /// In es, this message translates to:
  /// **'No se pudo sincronizar: {error}'**
  String syncFailed(Object error);

  /// No description provided for @syncUploadLocal.
  ///
  /// In es, this message translates to:
  /// **'Subir la versión de este dispositivo'**
  String get syncUploadLocal;

  /// No description provided for @restoreNoProvider.
  ///
  /// In es, this message translates to:
  /// **'Configure un proveedor de sync primero.'**
  String get restoreNoProvider;

  /// No description provided for @restoreSearchFailed.
  ///
  /// In es, this message translates to:
  /// **'No se pudo buscar la bóveda remota: {error}'**
  String restoreSearchFailed(Object error);

  /// No description provided for @restoreTitle.
  ///
  /// In es, this message translates to:
  /// **'Restaurar bóveda existente'**
  String get restoreTitle;

  /// No description provided for @restoreIntro.
  ///
  /// In es, this message translates to:
  /// **'Conecte el mismo proveedor de sync que ya usa en su otro dispositivo: vamos a bajar su bóveda desde ahí.'**
  String get restoreIntro;

  /// No description provided for @restoreSetUpProvider.
  ///
  /// In es, this message translates to:
  /// **'Configurar proveedor de sync'**
  String get restoreSetUpProvider;

  /// No description provided for @restoreFindVault.
  ///
  /// In es, this message translates to:
  /// **'Buscar mi bóveda'**
  String get restoreFindVault;

  /// No description provided for @restoreSearching.
  ///
  /// In es, this message translates to:
  /// **'Buscando su bóveda…'**
  String get restoreSearching;

  /// No description provided for @restoreSearchingDetail.
  ///
  /// In es, this message translates to:
  /// **'Revisando el proveedor de sync configurado.'**
  String get restoreSearchingDetail;

  /// No description provided for @restoreNotFoundTitle.
  ///
  /// In es, this message translates to:
  /// **'No hay ninguna bóveda ahí todavía'**
  String get restoreNotFoundTitle;

  /// No description provided for @restoreNotFoundBody.
  ///
  /// In es, this message translates to:
  /// **'El proveedor está conectado, pero no encontramos ninguna bóveda subida. Si el otro dispositivo todavía no sincronizó, pruebe desde ahí primero.'**
  String get restoreNotFoundBody;

  /// No description provided for @commonBack.
  ///
  /// In es, this message translates to:
  /// **'Volver'**
  String get commonBack;

  /// No description provided for @restoreFoundTitle.
  ///
  /// In es, this message translates to:
  /// **'Encontramos su bóveda'**
  String get restoreFoundTitle;

  /// No description provided for @restoreFoundBody.
  ///
  /// In es, this message translates to:
  /// **'Ingrese su contraseña maestra para desbloquearla.'**
  String get restoreFoundBody;

  /// No description provided for @commonMasterPassword.
  ///
  /// In es, this message translates to:
  /// **'Contraseña maestra'**
  String get commonMasterPassword;

  /// No description provided for @commonMasterPasswordRequired.
  ///
  /// In es, this message translates to:
  /// **'Ingrese su contraseña maestra'**
  String get commonMasterPasswordRequired;

  /// No description provided for @commonWrongPassword.
  ///
  /// In es, this message translates to:
  /// **'Contraseña incorrecta'**
  String get commonWrongPassword;

  /// No description provided for @restoreConfirm.
  ///
  /// In es, this message translates to:
  /// **'Restaurar bóveda'**
  String get restoreConfirm;

  /// No description provided for @cloudNotConnected.
  ///
  /// In es, this message translates to:
  /// **'Sin cuenta conectada. {scopeNote}'**
  String cloudNotConnected(Object scopeNote);

  /// No description provided for @cloudConnectedAs.
  ///
  /// In es, this message translates to:
  /// **'Conectado como {email}'**
  String cloudConnectedAs(Object email);

  /// No description provided for @cloudDisconnect.
  ///
  /// In es, this message translates to:
  /// **'Desconectar'**
  String get cloudDisconnect;

  /// No description provided for @pwChangedBanner.
  ///
  /// In es, this message translates to:
  /// **'La contraseña maestra se cambió en otro dispositivo. Ingrese la nueva para seguir sincronizando.'**
  String get pwChangedBanner;

  /// No description provided for @pwChangedEnterNew.
  ///
  /// In es, this message translates to:
  /// **'Ingresar contraseña nueva'**
  String get pwChangedEnterNew;

  /// No description provided for @pwChangedNotNew.
  ///
  /// In es, this message translates to:
  /// **'No es la contraseña nueva'**
  String get pwChangedNotNew;

  /// No description provided for @commonCouldNotComplete.
  ///
  /// In es, this message translates to:
  /// **'No se pudo completar: {error}'**
  String commonCouldNotComplete(Object error);

  /// No description provided for @pwChangedDialogTitle.
  ///
  /// In es, this message translates to:
  /// **'Contraseña maestra nueva'**
  String get pwChangedDialogTitle;

  /// No description provided for @pwChangedDialogBody.
  ///
  /// In es, this message translates to:
  /// **'Ingrese la contraseña que puso en el otro dispositivo. Los cambios que hizo aquí se conservan.'**
  String get pwChangedDialogBody;

  /// No description provided for @pwChangedNewPassword.
  ///
  /// In es, this message translates to:
  /// **'Contraseña nueva'**
  String get pwChangedNewPassword;

  /// No description provided for @commonContinue.
  ///
  /// In es, this message translates to:
  /// **'Continuar'**
  String get commonContinue;

  /// No description provided for @syncHomeMovedBanner.
  ///
  /// In es, this message translates to:
  /// **'Su bóveda se mudó a {provider}. Conecte {provider} en este dispositivo para seguir sincronizando.'**
  String syncHomeMovedBanner(Object provider);

  /// No description provided for @syncHomeGoToSync.
  ///
  /// In es, this message translates to:
  /// **'Ir a Sincronización'**
  String get syncHomeGoToSync;

  /// No description provided for @errorSyncHomeMismatch.
  ///
  /// In es, this message translates to:
  /// **'Su bóveda se sincroniza con {home}, pero este dispositivo está conectado a {active}. Conecte {home} en Sincronización para seguir.'**
  String errorSyncHomeMismatch(Object home, Object active);

  /// No description provided for @errorRemoteDifferentVault.
  ///
  /// In es, this message translates to:
  /// **'La nube tiene una bóveda distinta a la suya. No se cambió nada en este dispositivo.'**
  String get errorRemoteDifferentVault;

  /// No description provided for @errorRemoteNotAuthentic.
  ///
  /// In es, this message translates to:
  /// **'La bóveda de la nube no se pudo verificar (está dañada, fue modificada o usa otra contraseña). No se cambió nada en este dispositivo.'**
  String get errorRemoteNotAuthentic;

  /// No description provided for @errorRemotePasswordChanged.
  ///
  /// In es, this message translates to:
  /// **'La contraseña maestra se cambió en otro dispositivo. Ingrese la contraseña nueva para seguir sincronizando.'**
  String get errorRemotePasswordChanged;

  /// No description provided for @errorRemoteRollback.
  ///
  /// In es, this message translates to:
  /// **'La nube tiene una versión más vieja que la que este dispositivo ya sincronizó: puede ser una copia antigua restaurada o una manipulación. No se cambió nada en este dispositivo.'**
  String get errorRemoteRollback;

  /// No description provided for @errorIncorrectCurrentPassword.
  ///
  /// In es, this message translates to:
  /// **'La contraseña actual no es correcta.'**
  String get errorIncorrectCurrentPassword;

  /// No description provided for @errorPreviousPasswordRequired.
  ///
  /// In es, this message translates to:
  /// **'Este dispositivo tiene cambios sin sincronizar. Ingrese también la contraseña anterior para conservarlos.'**
  String get errorPreviousPasswordRequired;

  /// No description provided for @errorIncorrectPreviousPassword.
  ///
  /// In es, this message translates to:
  /// **'La contraseña anterior no es correcta.'**
  String get errorIncorrectPreviousPassword;

  /// No description provided for @errorUnknownImportFormat.
  ///
  /// In es, this message translates to:
  /// **'Formato no reconocido: .{extension}. Use un XML de SafeInCloud, un CSV, un JSON de Bitwarden o un respaldo .lockspire.'**
  String errorUnknownImportFormat(Object extension);

  /// No description provided for @errorVaultWriteConflict.
  ///
  /// In es, this message translates to:
  /// **'La bóveda cambió en disco desde que se abrió y no se sobrescribió. Vuelva a abrirla antes de guardar de nuevo.'**
  String get errorVaultWriteConflict;

  /// No description provided for @errorIncorrectBackupPassword.
  ///
  /// In es, this message translates to:
  /// **'La contraseña no abre este respaldo. Es la contraseña maestra que tenía la bóveda cuando se hizo.'**
  String get errorIncorrectBackupPassword;

  /// No description provided for @errorUnsupportedVaultFormat.
  ///
  /// In es, this message translates to:
  /// **'Esta bóveda se creó con una versión más nueva de Lockspire (formato {version}). Actualice la app para abrirla.'**
  String errorUnsupportedVaultFormat(int version);

  /// No description provided for @errorUnsafeKdfParams.
  ///
  /// In es, this message translates to:
  /// **'El archivo de bóveda pide parámetros de cifrado fuera de lo normal. Puede estar dañado o haber sido modificado; no se abrió.'**
  String get errorUnsafeKdfParams;

  /// No description provided for @masterPasswordTooShort.
  ///
  /// In es, this message translates to:
  /// **'Use al menos {count} caracteres'**
  String masterPasswordTooShort(int count);

  /// No description provided for @masterPasswordTooRepetitive.
  ///
  /// In es, this message translates to:
  /// **'Tiene demasiados caracteres repetidos'**
  String get masterPasswordTooRepetitive;

  /// No description provided for @masterPasswordTooWeak.
  ///
  /// In es, this message translates to:
  /// **'Es demasiado fácil de adivinar: sume palabras, mayúsculas, números o símbolos'**
  String get masterPasswordTooWeak;

  /// No description provided for @errorVaultLocked.
  ///
  /// In es, this message translates to:
  /// **'La bóveda tiene que estar desbloqueada.'**
  String get errorVaultLocked;

  /// No description provided for @errorNotAVaultFile.
  ///
  /// In es, this message translates to:
  /// **'No es un archivo de bóveda de Lockspire válido.'**
  String get errorNotAVaultFile;

  /// No description provided for @errorSyncNotConfigured.
  ///
  /// In es, this message translates to:
  /// **'Configure un proveedor de sync primero (WebDAV, Google Drive u OneDrive).'**
  String get errorSyncNotConfigured;

  /// No description provided for @errorSyncNothingToSync.
  ///
  /// In es, this message translates to:
  /// **'No hay bóveda ni en este dispositivo ni en la nube.'**
  String get errorSyncNothingToSync;

  /// No description provided for @errorSyncConnectFailed.
  ///
  /// In es, this message translates to:
  /// **'No se pudo conectar con {provider}.'**
  String errorSyncConnectFailed(Object provider);

  /// No description provided for @errorSyncConnectVaultCloud.
  ///
  /// In es, this message translates to:
  /// **'Conecte la nube de su bóveda en Sincronización.'**
  String get errorSyncConnectVaultCloud;

  /// No description provided for @errorRemoteVaultMissing.
  ///
  /// In es, this message translates to:
  /// **'No hay bóveda en {provider} todavía.'**
  String errorRemoteVaultMissing(Object provider);

  /// No description provided for @errorRemoteUploadFailed.
  ///
  /// In es, this message translates to:
  /// **'No se pudo subir la bóveda a {provider}.'**
  String errorRemoteUploadFailed(Object provider);

  /// No description provided for @errorWebdavInsecureUrl.
  ///
  /// In es, this message translates to:
  /// **'El servidor WebDAV usa http:// sin cifrar. Cambie la URL a https:// en Sincronización.'**
  String get errorWebdavInsecureUrl;

  /// No description provided for @errorWebdavInvalidUrl.
  ///
  /// In es, this message translates to:
  /// **'La URL del servidor WebDAV no es válida.'**
  String get errorWebdavInvalidUrl;

  /// No description provided for @errorAccountEmailUnreadable.
  ///
  /// In es, this message translates to:
  /// **'No se pudo leer el email de la cuenta de {provider}.'**
  String errorAccountEmailUnreadable(Object provider);

  /// No description provided for @errorOauthBrowserFailed.
  ///
  /// In es, this message translates to:
  /// **'No se pudo abrir el navegador del sistema.'**
  String get errorOauthBrowserFailed;

  /// No description provided for @errorOauthTimedOut.
  ///
  /// In es, this message translates to:
  /// **'Se agotó el tiempo para iniciar sesión en {provider}. Pruebe de nuevo.'**
  String errorOauthTimedOut(Object provider);

  /// No description provided for @errorOauthNoCode.
  ///
  /// In es, this message translates to:
  /// **'No se recibió el código de autorización.'**
  String get errorOauthNoCode;

  /// No description provided for @errorOauthLoginClosed.
  ///
  /// In es, this message translates to:
  /// **'Se cerró la espera del inicio de sesión.'**
  String get errorOauthLoginClosed;

  /// No description provided for @errorOauthTokenFailed.
  ///
  /// In es, this message translates to:
  /// **'No se pudo obtener el acceso a OneDrive: {detail}'**
  String errorOauthTokenFailed(Object detail);

  /// No description provided for @errorOauthRefreshFailed.
  ///
  /// In es, this message translates to:
  /// **'No se pudo renovar la sesión de OneDrive: {detail}'**
  String errorOauthRefreshFailed(Object detail);

  /// No description provided for @errorNativeHostMissing.
  ///
  /// In es, this message translates to:
  /// **'No se encontró el componente de conexión con el navegador en {path}. Reinstale Lockspire.'**
  String errorNativeHostMissing(Object path);

  /// No description provided for @errorNativeHostElevationCancelled.
  ///
  /// In es, this message translates to:
  /// **'No se completó el registro para todo el equipo (¿se canceló el permiso de administrador?).'**
  String get errorNativeHostElevationCancelled;

  /// No description provided for @errorNativeHostWindowsOnly.
  ///
  /// In es, this message translates to:
  /// **'Solo disponible en Windows por ahora.'**
  String get errorNativeHostWindowsOnly;

  /// No description provided for @errorNoSupportedBrowser.
  ///
  /// In es, this message translates to:
  /// **'No se encontró ningún navegador compatible.'**
  String get errorNoSupportedBrowser;

  /// No description provided for @errorImportInvalidJson.
  ///
  /// In es, this message translates to:
  /// **'El archivo no es un JSON válido.'**
  String get errorImportInvalidJson;

  /// No description provided for @errorImportNotBitwardenJson.
  ///
  /// In es, this message translates to:
  /// **'No es un export JSON de Bitwarden.'**
  String get errorImportNotBitwardenJson;

  /// No description provided for @errorImportBitwardenEncrypted.
  ///
  /// In es, this message translates to:
  /// **'Este JSON de Bitwarden está cifrado. Expórtelo de nuevo eligiendo \"JSON\" (sin cifrar) para poder importarlo.'**
  String get errorImportBitwardenEncrypted;

  /// No description provided for @errorImportCsvUnclosedQuote.
  ///
  /// In es, this message translates to:
  /// **'El CSV tiene comillas sin cerrar.'**
  String get errorImportCsvUnclosedQuote;

  /// No description provided for @errorImportCsvEmpty.
  ///
  /// In es, this message translates to:
  /// **'El CSV está vacío.'**
  String get errorImportCsvEmpty;

  /// No description provided for @errorImportCsvNoPasswordColumn.
  ///
  /// In es, this message translates to:
  /// **'No se encontró una columna de contraseña. Exporte desde su gestor en CSV (Bitwarden, Chrome, Firefox o KeePassXC).'**
  String get errorImportCsvNoPasswordColumn;

  /// No description provided for @biometricWindowsHello.
  ///
  /// In es, this message translates to:
  /// **'Windows Hello'**
  String get biometricWindowsHello;

  /// No description provided for @biometricFingerprint.
  ///
  /// In es, this message translates to:
  /// **'la huella'**
  String get biometricFingerprint;

  /// No description provided for @crackTimeInstant.
  ///
  /// In es, this message translates to:
  /// **'instantáneo'**
  String get crackTimeInstant;

  /// No description provided for @crackTimeSeconds.
  ///
  /// In es, this message translates to:
  /// **'{count, plural, =1{1 segundo} other{{count} segundos}}'**
  String crackTimeSeconds(int count);

  /// No description provided for @crackTimeMinutes.
  ///
  /// In es, this message translates to:
  /// **'{count, plural, =1{1 minuto} other{{count} minutos}}'**
  String crackTimeMinutes(int count);

  /// No description provided for @crackTimeHours.
  ///
  /// In es, this message translates to:
  /// **'{count, plural, =1{1 hora} other{{count} horas}}'**
  String crackTimeHours(int count);

  /// No description provided for @crackTimeDays.
  ///
  /// In es, this message translates to:
  /// **'{count, plural, =1{1 día} other{{count} días}}'**
  String crackTimeDays(int count);

  /// No description provided for @crackTimeMonths.
  ///
  /// In es, this message translates to:
  /// **'{count, plural, =1{1 mes} other{{count} meses}}'**
  String crackTimeMonths(int count);

  /// No description provided for @crackTimeYears.
  ///
  /// In es, this message translates to:
  /// **'{count, plural, =1{1 año} other{{count} años}}'**
  String crackTimeYears(int count);

  /// No description provided for @crackTimeCenturies.
  ///
  /// In es, this message translates to:
  /// **'{count, plural, =1{1 siglo} other{{count} siglos}}'**
  String crackTimeCenturies(int count);

  /// No description provided for @crackTimeMillionsOfYears.
  ///
  /// In es, this message translates to:
  /// **'millones de años'**
  String get crackTimeMillionsOfYears;

  /// No description provided for @unlockPreviousPasswordNeeded.
  ///
  /// In es, this message translates to:
  /// **'Este dispositivo tiene cambios que aún no se sincronizaron. Para conservarlos, ingrese también la contraseña anterior.'**
  String get unlockPreviousPasswordNeeded;

  /// No description provided for @unlockPreviousPasswordWrong.
  ///
  /// In es, this message translates to:
  /// **'La contraseña anterior no es correcta'**
  String get unlockPreviousPasswordWrong;

  /// No description provided for @unlockWelcomeBack.
  ///
  /// In es, this message translates to:
  /// **'¡Hola de nuevo!'**
  String get unlockWelcomeBack;

  /// No description provided for @unlockPrompt.
  ///
  /// In es, this message translates to:
  /// **'Ingrese su contraseña para entrar a su bóveda'**
  String get unlockPrompt;

  /// No description provided for @unlockPasswordChangedElsewhere.
  ///
  /// In es, this message translates to:
  /// **'La contraseña maestra se cambió en otro dispositivo. Ingrese la nueva para entrar. Hasta entonces no se puede usar {method}.'**
  String unlockPasswordChangedElsewhere(Object method);

  /// No description provided for @unlockPeriodicReminder.
  ///
  /// In es, this message translates to:
  /// **'Por seguridad, cada tanto Lockspire le pide la contraseña maestra aunque use {method}, para que no se le olvide. Después vuelve a funcionar como siempre.'**
  String unlockPeriodicReminder(Object method);

  /// No description provided for @unlockPreviousPassword.
  ///
  /// In es, this message translates to:
  /// **'Contraseña anterior'**
  String get unlockPreviousPassword;

  /// No description provided for @unlockPreviousPasswordRequired.
  ///
  /// In es, this message translates to:
  /// **'Ingrese la contraseña anterior'**
  String get unlockPreviousPasswordRequired;

  /// No description provided for @unlockUnlocking.
  ///
  /// In es, this message translates to:
  /// **'Desbloqueando… esto puede tardar unos segundos (derivación de clave Argon2id)'**
  String get unlockUnlocking;

  /// No description provided for @unlockButton.
  ///
  /// In es, this message translates to:
  /// **'Desbloquear'**
  String get unlockButton;

  /// No description provided for @unlockEnterNewPassword.
  ///
  /// In es, this message translates to:
  /// **'Ingresar la contraseña nueva'**
  String get unlockEnterNewPassword;

  /// No description provided for @unlockNoNewPassword.
  ///
  /// In es, this message translates to:
  /// **'No tengo la contraseña nueva'**
  String get unlockNoNewPassword;

  /// No description provided for @unlockUseBiometric.
  ///
  /// In es, this message translates to:
  /// **'Usar {method}'**
  String unlockUseBiometric(Object method);

  /// No description provided for @createVaultTitle.
  ///
  /// In es, this message translates to:
  /// **'Crear bóveda'**
  String get createVaultTitle;

  /// No description provided for @createVaultHeading.
  ///
  /// In es, this message translates to:
  /// **'Cree su bóveda'**
  String get createVaultHeading;

  /// No description provided for @createVaultIntro.
  ///
  /// In es, this message translates to:
  /// **'Elija una contraseña maestra. Nunca se envía ni se guarda: si la olvida, no hay forma de recuperarla.'**
  String get createVaultIntro;

  /// No description provided for @createVaultMinLength.
  ///
  /// In es, this message translates to:
  /// **'Mínimo {count} caracteres'**
  String createVaultMinLength(int count);

  /// No description provided for @createVaultPasswordRequired.
  ///
  /// In es, this message translates to:
  /// **'Ingrese una contraseña'**
  String get createVaultPasswordRequired;

  /// No description provided for @createVaultConfirm.
  ///
  /// In es, this message translates to:
  /// **'Confirmar contraseña'**
  String get createVaultConfirm;

  /// No description provided for @createVaultMismatch.
  ///
  /// In es, this message translates to:
  /// **'No coincide con la contraseña anterior'**
  String get createVaultMismatch;

  /// No description provided for @createVaultCreating.
  ///
  /// In es, this message translates to:
  /// **'Creando bóveda… esto puede tardar unos segundos (derivación de clave Argon2id)'**
  String get createVaultCreating;

  /// No description provided for @createVaultFailed.
  ///
  /// In es, this message translates to:
  /// **'No se pudo crear la bóveda: {error}'**
  String createVaultFailed(Object error);

  /// No description provided for @createVaultRestoreLink.
  ///
  /// In es, this message translates to:
  /// **'¿Ya tiene una bóveda? Restaurarla desde la nube'**
  String get createVaultRestoreLink;

  /// No description provided for @changePwDone.
  ///
  /// In es, this message translates to:
  /// **'Contraseña maestra cambiada. Sus otros dispositivos se la pedirán la próxima vez que sincronicen.'**
  String get changePwDone;

  /// No description provided for @changePwCurrentWrong.
  ///
  /// In es, this message translates to:
  /// **'La contraseña actual no es correcta'**
  String get changePwCurrentWrong;

  /// No description provided for @changePwConflict.
  ///
  /// In es, this message translates to:
  /// **'La bóveda cambió mientras se guardaba. La nube ya tiene la contraseña nueva: sincronice y, cuando se la pida, ingrésela.'**
  String get changePwConflict;

  /// No description provided for @changePwFailed.
  ///
  /// In es, this message translates to:
  /// **'No se pudo cambiar la contraseña, así que sigue siendo la misma. {error}'**
  String changePwFailed(Object error);

  /// No description provided for @changePwTitle.
  ///
  /// In es, this message translates to:
  /// **'Cambiar contraseña maestra'**
  String get changePwTitle;

  /// No description provided for @changePwIntro.
  ///
  /// In es, this message translates to:
  /// **'Si tiene sincronización, primero se sincroniza y la bóveda nueva se sube a la nube: hace falta conexión. Las copias viejas que alguien ya tenga siguen abriéndose con la contraseña anterior.'**
  String get changePwIntro;

  /// No description provided for @changePwCurrent.
  ///
  /// In es, this message translates to:
  /// **'Contraseña actual'**
  String get changePwCurrent;

  /// No description provided for @changePwCurrentRequired.
  ///
  /// In es, this message translates to:
  /// **'Ingrese su contraseña actual'**
  String get changePwCurrentRequired;

  /// No description provided for @changePwNewHelper.
  ///
  /// In es, this message translates to:
  /// **'Mínimo {count} caracteres, difícil de adivinar'**
  String changePwNewHelper(int count);

  /// No description provided for @changePwMustDiffer.
  ///
  /// In es, this message translates to:
  /// **'Tiene que ser distinta de la actual'**
  String get changePwMustDiffer;

  /// No description provided for @changePwConfirmNew.
  ///
  /// In es, this message translates to:
  /// **'Confirmar contraseña nueva'**
  String get changePwConfirmNew;

  /// No description provided for @changePwMismatch.
  ///
  /// In es, this message translates to:
  /// **'No coincide con la contraseña nueva'**
  String get changePwMismatch;

  /// No description provided for @changePwShowPasswords.
  ///
  /// In es, this message translates to:
  /// **'Mostrar contraseñas'**
  String get changePwShowPasswords;

  /// No description provided for @changePwButton.
  ///
  /// In es, this message translates to:
  /// **'Cambiar contraseña'**
  String get changePwButton;

  /// No description provided for @commonRetry.
  ///
  /// In es, this message translates to:
  /// **'Reintentar'**
  String get commonRetry;

  /// No description provided for @strengthWeak.
  ///
  /// In es, this message translates to:
  /// **'Débil'**
  String get strengthWeak;

  /// No description provided for @strengthFair.
  ///
  /// In es, this message translates to:
  /// **'Regular'**
  String get strengthFair;

  /// No description provided for @strengthStrong.
  ///
  /// In es, this message translates to:
  /// **'Segura'**
  String get strengthStrong;

  /// No description provided for @strengthLabel.
  ///
  /// In es, this message translates to:
  /// **'{level} — tiempo estimado para descifrarla: {time}'**
  String strengthLabel(Object level, Object time);

  /// No description provided for @deleteEntriesBody.
  ///
  /// In es, this message translates to:
  /// **'Se eliminan de la bóveda en este dispositivo y en los demás al sincronizar.'**
  String get deleteEntriesBody;

  /// No description provided for @commonDelete.
  ///
  /// In es, this message translates to:
  /// **'Eliminar'**
  String get commonDelete;

  /// No description provided for @biometricOptInTitle.
  ///
  /// In es, this message translates to:
  /// **'¿Activar desbloqueo con {methodName}?'**
  String biometricOptInTitle(Object methodName);

  /// No description provided for @biometricOptInBody.
  ///
  /// In es, this message translates to:
  /// **'En vez de escribir la contraseña maestra cada vez, podrá desbloquear la bóveda con {methodName}. Puede cambiarlo después desde \"Seguridad\".'**
  String biometricOptInBody(Object methodName);

  /// No description provided for @commonNotNow.
  ///
  /// In es, this message translates to:
  /// **'Ahora no'**
  String get commonNotNow;

  /// No description provided for @commonTurnOn.
  ///
  /// In es, this message translates to:
  /// **'Activar'**
  String get commonTurnOn;

  /// No description provided for @entryTypePassword.
  ///
  /// In es, this message translates to:
  /// **'Contraseña'**
  String get entryTypePassword;

  /// No description provided for @entryTypeCard.
  ///
  /// In es, this message translates to:
  /// **'Tarjeta'**
  String get entryTypeCard;

  /// No description provided for @entryTypeDocument.
  ///
  /// In es, this message translates to:
  /// **'Documento'**
  String get entryTypeDocument;

  /// No description provided for @selectionCancel.
  ///
  /// In es, this message translates to:
  /// **'Cancelar selección'**
  String get selectionCancel;

  /// No description provided for @selectionCount.
  ///
  /// In es, this message translates to:
  /// **'{count, plural, =1{1 seleccionada} other{{count} seleccionadas}}'**
  String selectionCount(int count);

  /// No description provided for @selectionClear.
  ///
  /// In es, this message translates to:
  /// **'Quitar selección'**
  String get selectionClear;

  /// No description provided for @selectionAll.
  ///
  /// In es, this message translates to:
  /// **'Seleccionar todo'**
  String get selectionAll;

  /// No description provided for @selectionDelete.
  ///
  /// In es, this message translates to:
  /// **'Eliminar seleccionadas'**
  String get selectionDelete;

  /// No description provided for @selectionStart.
  ///
  /// In es, this message translates to:
  /// **'Seleccionar'**
  String get selectionStart;

  /// No description provided for @commonLock.
  ///
  /// In es, this message translates to:
  /// **'Bloquear'**
  String get commonLock;

  /// No description provided for @vaultSearchHint.
  ///
  /// In es, this message translates to:
  /// **'Buscar por título, usuario o sitio'**
  String get vaultSearchHint;

  /// No description provided for @commonAdd.
  ///
  /// In es, this message translates to:
  /// **'Agregar'**
  String get commonAdd;

  /// No description provided for @autofillSettingsOpenFailed.
  ///
  /// In es, this message translates to:
  /// **'No se pudo abrir la configuración.'**
  String get autofillSettingsOpenFailed;

  /// No description provided for @securityTitle.
  ///
  /// In es, this message translates to:
  /// **'Seguridad'**
  String get securityTitle;

  /// No description provided for @securityChangePwHint.
  ///
  /// In es, this message translates to:
  /// **'Hágalo si cree que alguien pudo conocerla.'**
  String get securityChangePwHint;

  /// No description provided for @securityUnlockWith.
  ///
  /// In es, this message translates to:
  /// **'Desbloquear con {method}'**
  String securityUnlockWith(Object method);

  /// No description provided for @securityUnlockWithHint.
  ///
  /// In es, this message translates to:
  /// **'Use {method} en vez de escribir la contraseña maestra cada vez.'**
  String securityUnlockWithHint(Object method);

  /// No description provided for @autofillSettingsTitle.
  ///
  /// In es, this message translates to:
  /// **'Autocompletado'**
  String get autofillSettingsTitle;

  /// No description provided for @autofillSettingsHint.
  ///
  /// In es, this message translates to:
  /// **'Active Lockspire como servicio de autocompletado para que aparezca como opción al iniciar sesión en otras apps — incluye logins dentro de un navegador embebido (ej. WebView).'**
  String get autofillSettingsHint;

  /// No description provided for @autofillSettingsButton.
  ///
  /// In es, this message translates to:
  /// **'Activar como autocompletado'**
  String get autofillSettingsButton;

  /// No description provided for @securityBiometricNotSetUp.
  ///
  /// In es, this message translates to:
  /// **'Este dispositivo no tiene {method} configurado.'**
  String securityBiometricNotSetUp(Object method);

  /// No description provided for @securityBiometricSetUpHint.
  ///
  /// In es, this message translates to:
  /// **'Configure {method} en los ajustes del sistema para poder activarlo aquí.'**
  String securityBiometricSetUpHint(Object method);

  /// No description provided for @securityBiometricUnavailable.
  ///
  /// In es, this message translates to:
  /// **'No disponible en este dispositivo.'**
  String get securityBiometricUnavailable;

  /// No description provided for @securityReminderTitle.
  ///
  /// In es, this message translates to:
  /// **'Pedir la contraseña maestra cada'**
  String get securityReminderTitle;

  /// No description provided for @securityReminderHint.
  ///
  /// In es, this message translates to:
  /// **'Aunque use {method}, pasado este tiempo Lockspire le pide la contraseña una vez, para que no se le olvide. Si la olvida, la bóveda no se puede recuperar.'**
  String securityReminderHint(Object method);

  /// No description provided for @securityAutoLock.
  ///
  /// In es, this message translates to:
  /// **'Bloqueo automático'**
  String get securityAutoLock;

  /// No description provided for @securityAutoLock15Warning.
  ///
  /// In es, this message translates to:
  /// **'Más cómodo, pero la bóveda queda abierta más tiempo si se aleja del equipo.'**
  String get securityAutoLock15Warning;

  /// No description provided for @siteIconsTitle.
  ///
  /// In es, this message translates to:
  /// **'Íconos de los sitios'**
  String get siteIconsTitle;

  /// No description provided for @siteIconsHint.
  ///
  /// In es, this message translates to:
  /// **'Descarga el ícono de cada sitio guardado directamente del sitio, sin servicios de terceros, y lo guarda cifrado en su bóveda. Cada sitio ve una visita desde su conexión. Sin activarlo, se muestra la inicial.'**
  String get siteIconsHint;

  /// No description provided for @siteIconsFallback.
  ///
  /// In es, this message translates to:
  /// **'Completar los que falten con DuckDuckGo'**
  String get siteIconsFallback;

  /// No description provided for @siteIconsFallbackHint.
  ///
  /// In es, this message translates to:
  /// **'Para los sitios que no ofrecen ícono, se lo pide a DuckDuckGo. DuckDuckGo recibe solo esos dominios, nunca sus usuarios ni contraseñas.'**
  String get siteIconsFallbackHint;

  /// No description provided for @siteIconsRetry.
  ///
  /// In es, this message translates to:
  /// **'Volver a buscar los que faltan'**
  String get siteIconsRetry;

  /// No description provided for @vaultNoResults.
  ///
  /// In es, this message translates to:
  /// **'No se encontraron resultados'**
  String get vaultNoResults;

  /// No description provided for @vaultEmpty.
  ///
  /// In es, this message translates to:
  /// **'Todavía no ha guardado ninguna contraseña'**
  String get vaultEmpty;

  /// No description provided for @vaultEmptyHint.
  ///
  /// In es, this message translates to:
  /// **'Toque el botón \"+\" para agregar la primera'**
  String get vaultEmptyHint;

  /// No description provided for @generatorRandom.
  ///
  /// In es, this message translates to:
  /// **'Aleatoria'**
  String get generatorRandom;

  /// No description provided for @generatorMemorable.
  ///
  /// In es, this message translates to:
  /// **'Fácil de recordar'**
  String get generatorMemorable;

  /// No description provided for @generatorLength.
  ///
  /// In es, this message translates to:
  /// **'{count} caracteres'**
  String generatorLength(int count);

  /// No description provided for @deleteEntriesTitle.
  ///
  /// In es, this message translates to:
  /// **'{count, plural, =1{¿Eliminar 1 entrada?} other{¿Eliminar {count} entradas?}}'**
  String deleteEntriesTitle(int count);

  /// No description provided for @deleteEntriesDone.
  ///
  /// In es, this message translates to:
  /// **'{count, plural, =1{Se eliminó 1 entrada} other{Se eliminaron {count} entradas}}'**
  String deleteEntriesDone(int count);

  /// No description provided for @commonDays.
  ///
  /// In es, this message translates to:
  /// **'{count, plural, =1{1 día} other{{count} días}}'**
  String commonDays(int count);

  /// No description provided for @commonMinutesShort.
  ///
  /// In es, this message translates to:
  /// **'{count} min'**
  String commonMinutesShort(int count);

  /// No description provided for @securityAutoLockHintAndroid.
  ///
  /// In es, this message translates to:
  /// **'La bóveda se bloquea sola cuando pasa este tiempo sin que use Lockspire. También se bloquea al salir de la app.'**
  String get securityAutoLockHintAndroid;

  /// No description provided for @securityAutoLockHintDesktop.
  ///
  /// In es, this message translates to:
  /// **'La bóveda se bloquea sola cuando pasa este tiempo sin que use Lockspire. También se bloquea al bloquear la sesión o suspender el equipo.'**
  String get securityAutoLockHintDesktop;

  /// No description provided for @entryConflict.
  ///
  /// In es, this message translates to:
  /// **'{error} Revise los datos e intente guardar de nuevo.'**
  String entryConflict(Object error);

  /// No description provided for @entrySaveFailed.
  ///
  /// In es, this message translates to:
  /// **'No se pudo guardar: {error}'**
  String entrySaveFailed(Object error);

  /// No description provided for @entryDeleteTitle.
  ///
  /// In es, this message translates to:
  /// **'¿Eliminar esta entrada?'**
  String get entryDeleteTitle;

  /// No description provided for @entryDeleteBody.
  ///
  /// In es, this message translates to:
  /// **'Se eliminará \"{title}\" de la bóveda.'**
  String entryDeleteBody(Object title);

  /// No description provided for @entryCopied.
  ///
  /// In es, this message translates to:
  /// **'Copiado: {label}. Se borra en {seconds} s o al bloquear'**
  String entryCopied(Object label, int seconds);

  /// No description provided for @fieldUsername.
  ///
  /// In es, this message translates to:
  /// **'Usuario'**
  String get fieldUsername;

  /// No description provided for @fieldPassword.
  ///
  /// In es, this message translates to:
  /// **'Contraseña'**
  String get fieldPassword;

  /// No description provided for @entryGeneratePassword.
  ///
  /// In es, this message translates to:
  /// **'Generar contraseña'**
  String get entryGeneratePassword;

  /// No description provided for @fieldTitle.
  ///
  /// In es, this message translates to:
  /// **'Título'**
  String get fieldTitle;

  /// No description provided for @entryTitleRequired.
  ///
  /// In es, this message translates to:
  /// **'Ingrese un título'**
  String get entryTitleRequired;

  /// No description provided for @entryWebsites.
  ///
  /// In es, this message translates to:
  /// **'Sitios web'**
  String get entryWebsites;

  /// No description provided for @fieldWebsite.
  ///
  /// In es, this message translates to:
  /// **'Sitio web'**
  String get fieldWebsite;

  /// No description provided for @entryAddWebsite.
  ///
  /// In es, this message translates to:
  /// **'Agregar sitio web'**
  String get entryAddWebsite;

  /// No description provided for @entryAndroidApps.
  ///
  /// In es, this message translates to:
  /// **'Apps Android'**
  String get entryAndroidApps;

  /// No description provided for @entryAppPackage.
  ///
  /// In es, this message translates to:
  /// **'App (paquete)'**
  String get entryAppPackage;

  /// No description provided for @entryAddApp.
  ///
  /// In es, this message translates to:
  /// **'Agregar app'**
  String get entryAddApp;

  /// No description provided for @entryOtherFields.
  ///
  /// In es, this message translates to:
  /// **'Otros campos'**
  String get entryOtherFields;

  /// No description provided for @entryAndroidApp.
  ///
  /// In es, this message translates to:
  /// **'App Android'**
  String get entryAndroidApp;

  /// No description provided for @entryField.
  ///
  /// In es, this message translates to:
  /// **'Campo'**
  String get entryField;

  /// No description provided for @fieldNotes.
  ///
  /// In es, this message translates to:
  /// **'Notas'**
  String get fieldNotes;

  /// No description provided for @entrySavedEncrypted.
  ///
  /// In es, this message translates to:
  /// **'Se guarda cifrada junto con el resto de su bóveda.'**
  String get entrySavedEncrypted;

  /// No description provided for @fieldCopy.
  ///
  /// In es, this message translates to:
  /// **'Copiar {field}'**
  String fieldCopy(Object field);

  /// No description provided for @commonShow.
  ///
  /// In es, this message translates to:
  /// **'Mostrar'**
  String get commonShow;

  /// No description provided for @commonHide.
  ///
  /// In es, this message translates to:
  /// **'Ocultar'**
  String get commonHide;

  /// No description provided for @commonRemove.
  ///
  /// In es, this message translates to:
  /// **'Quitar'**
  String get commonRemove;

  /// No description provided for @customFieldRemove.
  ///
  /// In es, this message translates to:
  /// **'Quitar campo'**
  String get customFieldRemove;

  /// No description provided for @customFieldAdd.
  ///
  /// In es, this message translates to:
  /// **'Agregar campo'**
  String get customFieldAdd;

  /// No description provided for @customFieldNameRequired.
  ///
  /// In es, this message translates to:
  /// **'Ingrese un nombre'**
  String get customFieldNameRequired;

  /// No description provided for @customFieldNameTaken.
  ///
  /// In es, this message translates to:
  /// **'Ya hay un campo con ese nombre'**
  String get customFieldNameTaken;

  /// No description provided for @customFieldNew.
  ///
  /// In es, this message translates to:
  /// **'Nuevo campo'**
  String get customFieldNew;

  /// No description provided for @customFieldName.
  ///
  /// In es, this message translates to:
  /// **'Nombre del campo'**
  String get customFieldName;

  /// No description provided for @customFieldNameHint.
  ///
  /// In es, this message translates to:
  /// **'Por ejemplo: Pregunta secreta'**
  String get customFieldNameHint;

  /// No description provided for @customFieldHidden.
  ///
  /// In es, this message translates to:
  /// **'Ocultar el valor'**
  String get customFieldHidden;

  /// No description provided for @customFieldHiddenHint.
  ///
  /// In es, this message translates to:
  /// **'Para claves, PIN y otros datos sensibles'**
  String get customFieldHiddenHint;

  /// No description provided for @fieldCardNumber.
  ///
  /// In es, this message translates to:
  /// **'Número de tarjeta'**
  String get fieldCardNumber;

  /// No description provided for @fieldCardHolder.
  ///
  /// In es, this message translates to:
  /// **'Titular'**
  String get fieldCardHolder;

  /// No description provided for @fieldExpiry.
  ///
  /// In es, this message translates to:
  /// **'Vence'**
  String get fieldExpiry;

  /// No description provided for @fieldCardExpiryHint.
  ///
  /// In es, this message translates to:
  /// **'MM/AA'**
  String get fieldCardExpiryHint;

  /// No description provided for @fieldCvv.
  ///
  /// In es, this message translates to:
  /// **'CVV'**
  String get fieldCvv;

  /// No description provided for @fieldPin.
  ///
  /// In es, this message translates to:
  /// **'PIN'**
  String get fieldPin;

  /// No description provided for @fieldDocNumber.
  ///
  /// In es, this message translates to:
  /// **'Número'**
  String get fieldDocNumber;

  /// No description provided for @fieldDocName.
  ///
  /// In es, this message translates to:
  /// **'Nombre'**
  String get fieldDocName;

  /// No description provided for @fieldBirthDate.
  ///
  /// In es, this message translates to:
  /// **'Fecha de nacimiento'**
  String get fieldBirthDate;

  /// No description provided for @fieldIssued.
  ///
  /// In es, this message translates to:
  /// **'Expedido'**
  String get fieldIssued;

  /// No description provided for @fieldDateHint.
  ///
  /// In es, this message translates to:
  /// **'DD/MM/AAAA'**
  String get fieldDateHint;

  /// No description provided for @fieldWebsiteN.
  ///
  /// In es, this message translates to:
  /// **'Sitio web {n}'**
  String fieldWebsiteN(Object n);

  /// No description provided for @fieldAppN.
  ///
  /// In es, this message translates to:
  /// **'App {n}'**
  String fieldAppN(Object n);

  /// No description provided for @fieldGenerationMode.
  ///
  /// In es, this message translates to:
  /// **'Modo de generación'**
  String get fieldGenerationMode;

  /// No description provided for @fieldGenerationParam.
  ///
  /// In es, this message translates to:
  /// **'Parámetro de generación'**
  String get fieldGenerationParam;

  /// No description provided for @historyTitle.
  ///
  /// In es, this message translates to:
  /// **'Valores anteriores'**
  String get historyTitle;

  /// No description provided for @historyHint.
  ///
  /// In es, this message translates to:
  /// **'Lo que tenían antes estos campos: al editarlos, al actualizarlos desde el navegador, al importar o al resolverse solo un cambio en otro dispositivo.'**
  String get historyHint;

  /// No description provided for @historyCopy.
  ///
  /// In es, this message translates to:
  /// **'Copiar el valor anterior'**
  String get historyCopy;

  /// No description provided for @entryNewTitle.
  ///
  /// In es, this message translates to:
  /// **'{type, select, card{Nueva tarjeta} document{Nuevo documento} note{Nueva nota} passkey{Nueva passkey} other{Nueva contraseña}}'**
  String entryNewTitle(String type);

  /// No description provided for @entryEditTitle.
  ///
  /// In es, this message translates to:
  /// **'{type, select, card{Editar tarjeta} document{Editar documento} note{Editar nota} passkey{Editar passkey} other{Editar contraseña}}'**
  String entryEditTitle(String type);

  /// No description provided for @importReadFailed.
  ///
  /// In es, this message translates to:
  /// **'No se pudo leer el archivo: {error}'**
  String importReadFailed(Object error);

  /// No description provided for @importConflict.
  ///
  /// In es, this message translates to:
  /// **'{error} Vuelva a intentar importar.'**
  String importConflict(Object error);

  /// No description provided for @importFailed.
  ///
  /// In es, this message translates to:
  /// **'No se pudo importar: {error}'**
  String importFailed(Object error);

  /// No description provided for @importDoneTitle.
  ///
  /// In es, this message translates to:
  /// **'Importación completada'**
  String get importDoneTitle;

  /// No description provided for @importDoneUnencrypted.
  ///
  /// In es, this message translates to:
  /// **'{count, plural, =1{Se importó 1 entrada} other{Se importaron {count} entradas}}. Por su seguridad: el archivo que eligió no está cifrado. Bórrelo del lugar donde lo guardó (y de la papelera): Lockspire no puede borrarlo por usted.'**
  String importDoneUnencrypted(int count);

  /// No description provided for @importDoneBackup.
  ///
  /// In es, this message translates to:
  /// **'{count, plural, =1{Se importó 1 entrada} other{Se importaron {count} entradas}} desde el respaldo.'**
  String importDoneBackup(int count);

  /// No description provided for @commonGotIt.
  ///
  /// In es, this message translates to:
  /// **'Entendido'**
  String get commonGotIt;

  /// No description provided for @importTitle.
  ///
  /// In es, this message translates to:
  /// **'Importar'**
  String get importTitle;

  /// No description provided for @importIntro.
  ///
  /// In es, this message translates to:
  /// **'Elija el archivo que exportó desde su otro gestor, o un respaldo de Lockspire. Se lee directo en memoria, sin guardar ninguna copia, y nunca se duplican entradas que ya tiene.'**
  String get importIntro;

  /// No description provided for @importBitwardenDetail.
  ///
  /// In es, this message translates to:
  /// **'CSV o JSON sin cifrar'**
  String get importBitwardenDetail;

  /// No description provided for @importOthersSource.
  ///
  /// In es, this message translates to:
  /// **'Chrome, Edge, Firefox, KeePassXC y otros'**
  String get importOthersSource;

  /// No description provided for @importLockspireBackup.
  ///
  /// In es, this message translates to:
  /// **'Respaldo de Lockspire'**
  String get importLockspireBackup;

  /// No description provided for @importLockspireBackupDetail.
  ///
  /// In es, this message translates to:
  /// **'.lockspire, con su contraseña'**
  String get importLockspireBackupDetail;

  /// No description provided for @importChooseFile.
  ///
  /// In es, this message translates to:
  /// **'Elegir archivo'**
  String get importChooseFile;

  /// No description provided for @importNothingNew.
  ///
  /// In es, this message translates to:
  /// **'No hay entradas nuevas'**
  String get importNothingNew;

  /// No description provided for @importWillImport.
  ///
  /// In es, this message translates to:
  /// **'{count, plural, =1{Se importará 1 entrada} other{Se importarán {count} entradas}}'**
  String importWillImport(int count);

  /// No description provided for @importSkipped.
  ///
  /// In es, this message translates to:
  /// **'{count, plural, =1{1 ya estaba en su bóveda y se omite} other{{count} ya estaban en su bóveda y se omiten}}'**
  String importSkipped(int count);

  /// No description provided for @importBackupPassword.
  ///
  /// In es, this message translates to:
  /// **'Contraseña del respaldo'**
  String get importBackupPassword;

  /// No description provided for @importBackupPasswordHint.
  ///
  /// In es, this message translates to:
  /// **'Ingrese la contraseña maestra que tenía la bóveda cuando se hizo este respaldo.'**
  String get importBackupPasswordHint;

  /// No description provided for @commonOpen.
  ///
  /// In es, this message translates to:
  /// **'Abrir'**
  String get commonOpen;

  /// No description provided for @exportUnencryptedTitle.
  ///
  /// In es, this message translates to:
  /// **'El archivo no va a estar cifrado'**
  String get exportUnencryptedTitle;

  /// No description provided for @exportUnencryptedConfirm.
  ///
  /// In es, this message translates to:
  /// **'Entiendo, exportar'**
  String get exportUnencryptedConfirm;

  /// No description provided for @exportWrongPassword.
  ///
  /// In es, this message translates to:
  /// **'La contraseña maestra no es correcta'**
  String get exportWrongPassword;

  /// No description provided for @exportSaveDialogTitle.
  ///
  /// In es, this message translates to:
  /// **'Guardar exportación'**
  String get exportSaveDialogTitle;

  /// No description provided for @exportFailed.
  ///
  /// In es, this message translates to:
  /// **'No se pudo exportar: {error}'**
  String exportFailed(Object error);

  /// No description provided for @exportDoneTitle.
  ///
  /// In es, this message translates to:
  /// **'Exportación lista'**
  String get exportDoneTitle;

  /// No description provided for @exportDoneBackup.
  ///
  /// In es, this message translates to:
  /// **'Se guardó el respaldo cifrado. Para abrirlo hace falta la contraseña maestra actual; si la cambia después, este respaldo sigue pidiendo la de hoy.'**
  String get exportDoneBackup;

  /// No description provided for @exportDoneFile.
  ///
  /// In es, this message translates to:
  /// **'Se guardó el {format}.'**
  String exportDoneFile(Object format);

  /// No description provided for @exportSkipped.
  ///
  /// In es, this message translates to:
  /// **'{count, plural, =1{1 tarjeta o documento no se incluyó} other{{count} tarjetas o documentos no se incluyeron}}: este formato solo lleva contraseñas.'**
  String exportSkipped(int count);

  /// No description provided for @exportDeleteReminder.
  ///
  /// In es, this message translates to:
  /// **'Recuerde borrarlo, también de la papelera, en cuanto lo importe en el otro gestor.'**
  String get exportDeleteReminder;

  /// No description provided for @exportTitle.
  ///
  /// In es, this message translates to:
  /// **'Exportar'**
  String get exportTitle;

  /// No description provided for @exportFormat.
  ///
  /// In es, this message translates to:
  /// **'Formato'**
  String get exportFormat;

  /// No description provided for @exportBackupLabel.
  ///
  /// In es, this message translates to:
  /// **'Respaldo de Lockspire (cifrado)'**
  String get exportBackupLabel;

  /// No description provided for @exportBackupHint.
  ///
  /// In es, this message translates to:
  /// **'Todo su contenido, cifrado con su contraseña maestra. Para guardarlo como respaldo o restaurarlo en otro Lockspire.'**
  String get exportBackupHint;

  /// No description provided for @exportUnencryptedNote.
  ///
  /// In es, this message translates to:
  /// **'Este formato no está cifrado. Úselo solo para pasar sus datos a otro gestor.'**
  String get exportUnencryptedNote;

  /// No description provided for @exportPasswordAlwaysAsked.
  ///
  /// In es, this message translates to:
  /// **'Para exportar siempre se pide la contraseña.'**
  String get exportPasswordAlwaysAsked;

  /// No description provided for @importCountPasswords.
  ///
  /// In es, this message translates to:
  /// **'{count, plural, =1{1 contraseña} other{{count} contraseñas}}'**
  String importCountPasswords(int count);

  /// No description provided for @importCountCards.
  ///
  /// In es, this message translates to:
  /// **'{count, plural, =1{1 tarjeta} other{{count} tarjetas}}'**
  String importCountCards(int count);

  /// No description provided for @importCountDocuments.
  ///
  /// In es, this message translates to:
  /// **'{count, plural, =1{1 documento} other{{count} documentos}}'**
  String importCountDocuments(int count);

  /// No description provided for @commonListAnd.
  ///
  /// In es, this message translates to:
  /// **'{first} y {last}'**
  String commonListAnd(Object first, Object last);

  /// No description provided for @exportUnencryptedBodyPasswords.
  ///
  /// In es, this message translates to:
  /// **'Cualquiera que abra el {format} verá todas sus contraseñas. Guárdelo solo el tiempo necesario para importarlo en el otro gestor y después bórrelo, también de la papelera. No lo suba a la nube ni lo envíe por correo o chat.'**
  String exportUnencryptedBodyPasswords(Object format);

  /// No description provided for @exportUnencryptedBodyAll.
  ///
  /// In es, this message translates to:
  /// **'Cualquiera que abra el {format} verá todas sus contraseñas, tarjetas y documentos. Guárdelo solo el tiempo necesario para importarlo en el otro gestor y después bórrelo, también de la papelera. No lo suba a la nube ni lo envíe por correo o chat.'**
  String exportUnencryptedBodyAll(Object format);

  /// No description provided for @exportBitwardenCsv.
  ///
  /// In es, this message translates to:
  /// **'CSV de Bitwarden'**
  String get exportBitwardenCsv;

  /// No description provided for @exportBitwardenCsvHint.
  ///
  /// In es, this message translates to:
  /// **'Sin cifrar. Lo aceptan Bitwarden, Proton Pass, 1Password, KeePassXC y otros. Tarjetas y documentos van como notas.'**
  String get exportBitwardenCsvHint;

  /// No description provided for @exportBitwardenJson.
  ///
  /// In es, this message translates to:
  /// **'JSON de Bitwarden'**
  String get exportBitwardenJson;

  /// No description provided for @exportBitwardenJsonHint.
  ///
  /// In es, this message translates to:
  /// **'Sin cifrar. Incluye tarjetas y documentos. Lo leen Bitwarden y otros gestores que importan desde Bitwarden.'**
  String get exportBitwardenJsonHint;

  /// No description provided for @exportChromeCsv.
  ///
  /// In es, this message translates to:
  /// **'CSV de Chrome'**
  String get exportChromeCsv;

  /// No description provided for @exportChromeCsvHint.
  ///
  /// In es, this message translates to:
  /// **'Sin cifrar. El formato más simple: lo importan Chrome, Edge, Firefox y Google Password Manager. Solo contraseñas.'**
  String get exportChromeCsvHint;

  /// No description provided for @browserRegistered.
  ///
  /// In es, this message translates to:
  /// **'Listo. Reinicie el navegador si ya estaba abierto.'**
  String get browserRegistered;

  /// No description provided for @browserUnregistered.
  ///
  /// In es, this message translates to:
  /// **'Lockspire ya no está conectado a los navegadores.'**
  String get browserUnregistered;

  /// No description provided for @browserRegisteredSystemWide.
  ///
  /// In es, this message translates to:
  /// **'Listo para todo el equipo. Reinicie el navegador si ya estaba abierto.'**
  String get browserRegisteredSystemWide;

  /// No description provided for @browserUnregisteredSystemWide.
  ///
  /// In es, this message translates to:
  /// **'Se quitó el registro para todo el equipo.'**
  String get browserUnregisteredSystemWide;

  /// No description provided for @browserTitle.
  ///
  /// In es, this message translates to:
  /// **'Navegador'**
  String get browserTitle;

  /// No description provided for @browserIntro.
  ///
  /// In es, this message translates to:
  /// **'Con la extensión de Lockspire para Chrome o Edge puede rellenar usuario y contraseña en los sitios web. La extensión le pide las credenciales a esta app; la bóveda nunca sale de acá y, si está bloqueada, la extensión le pide que la desbloquee primero.'**
  String get browserIntro;

  /// No description provided for @browserConnectedWith.
  ///
  /// In es, this message translates to:
  /// **'Conectado con {browsers}'**
  String browserConnectedWith(Object browsers);

  /// No description provided for @browserNotConnected.
  ///
  /// In es, this message translates to:
  /// **'No conectado con ningún navegador'**
  String get browserNotConnected;

  /// No description provided for @browserHostMissing.
  ///
  /// In es, this message translates to:
  /// **'Falta el componente \"lockspire-native-host\" junto a la app. Ver native-host/README.md.'**
  String get browserHostMissing;

  /// No description provided for @browserOtherCopy.
  ///
  /// In es, this message translates to:
  /// **'En {browsers} está registrada otra copia de Lockspire (por ejemplo, una versión vieja), y el navegador usa esa. Pulse \"Conectar con Chrome/Edge\" para que use esta.'**
  String browserOtherCopy(String browsers);

  /// No description provided for @browserOtherCopySystemWide.
  ///
  /// In es, this message translates to:
  /// **'El registro para todo el equipo apunta a otra copia de Lockspire, y el navegador puede estar usándola en vez de esta. Vuelva a registrarlo o quítelo.'**
  String get browserOtherCopySystemWide;

  /// No description provided for @browserReconnect.
  ///
  /// In es, this message translates to:
  /// **'Volver a conectar'**
  String get browserReconnect;

  /// No description provided for @browserConnect.
  ///
  /// In es, this message translates to:
  /// **'Conectar con Chrome/Edge'**
  String get browserConnect;

  /// No description provided for @browserSystemWide.
  ///
  /// In es, this message translates to:
  /// **'Para todo el equipo'**
  String get browserSystemWide;

  /// No description provided for @browserSystemWideHint.
  ///
  /// In es, this message translates to:
  /// **'Si la extensión sigue diciendo que no está conectada, su organización puede estar bloqueando las conexiones por usuario (política \"NativeMessagingUserLevelHosts\" de Chrome, visible en chrome://policy). En ese caso, registre Lockspire para todo el equipo: Windows le va a pedir permisos de administrador.'**
  String get browserSystemWideHint;

  /// No description provided for @browserSystemWideOn.
  ///
  /// In es, this message translates to:
  /// **'Registrado para todo el equipo'**
  String get browserSystemWideOn;

  /// No description provided for @browserSystemWideOff.
  ///
  /// In es, this message translates to:
  /// **'No registrado para todo el equipo'**
  String get browserSystemWideOff;

  /// No description provided for @browserReregister.
  ///
  /// In es, this message translates to:
  /// **'Volver a registrar'**
  String get browserReregister;

  /// No description provided for @browserRegisterSystemWide.
  ///
  /// In es, this message translates to:
  /// **'Registrar para todo el equipo'**
  String get browserRegisterSystemWide;

  /// No description provided for @browserRemoveRegistration.
  ///
  /// In es, this message translates to:
  /// **'Quitar registro'**
  String get browserRemoveRegistration;

  /// No description provided for @browserInstallExtension.
  ///
  /// In es, this message translates to:
  /// **'Instalar la extensión'**
  String get browserInstallExtension;

  /// No description provided for @browserInstallExtensionHint.
  ///
  /// In es, this message translates to:
  /// **'Mientras no esté publicada en la Chrome Web Store: abra chrome://extensions (o edge://extensions), active \"Modo de desarrollador\", elija \"Cargar descomprimida\" y seleccione la carpeta extension/dist del proyecto.'**
  String get browserInstallExtensionHint;

  /// No description provided for @bridgeRunning.
  ///
  /// In es, this message translates to:
  /// **'Lockspire está escuchando a la extensión.'**
  String get bridgeRunning;

  /// No description provided for @bridgeAnotherInstance.
  ///
  /// In es, this message translates to:
  /// **'Otra instancia de Lockspire ya atiende a la extensión.'**
  String get bridgeAnotherInstance;

  /// No description provided for @bridgeUnavailable.
  ///
  /// In es, this message translates to:
  /// **'No se pudo abrir el canal con la extensión en este equipo.'**
  String get bridgeUnavailable;

  /// No description provided for @bridgeUnsupported.
  ///
  /// In es, this message translates to:
  /// **'La extensión de navegador solo funciona en escritorio.'**
  String get bridgeUnsupported;

  /// No description provided for @commonStarting.
  ///
  /// In es, this message translates to:
  /// **'Iniciando…'**
  String get commonStarting;

  /// No description provided for @linkTitle.
  ///
  /// In es, this message translates to:
  /// **'¿Vincular este sitio?'**
  String get linkTitle;

  /// No description provided for @linkBody.
  ///
  /// In es, this message translates to:
  /// **'La extensión pide usar \"{title}\" en:'**
  String linkBody(Object title);

  /// No description provided for @linkNoUrl.
  ///
  /// In es, this message translates to:
  /// **'La entrada no tenía ninguna URL.'**
  String get linkNoUrl;

  /// No description provided for @linkReplacesUrl.
  ///
  /// In es, this message translates to:
  /// **'Reemplaza la URL actual: {url}'**
  String linkReplacesUrl(Object url);

  /// No description provided for @linkPhishingWarning.
  ///
  /// In es, this message translates to:
  /// **'Compruebe que la dirección sea la real: si es un sitio falso que imita al original, le estaría dando esta contraseña.'**
  String get linkPhishingWarning;

  /// No description provided for @linkConfirm.
  ///
  /// In es, this message translates to:
  /// **'Vincular'**
  String get linkConfirm;

  /// No description provided for @linkEntryGone.
  ///
  /// In es, this message translates to:
  /// **'La entrada ya no existe.'**
  String get linkEntryGone;

  /// No description provided for @linkDone.
  ///
  /// In es, this message translates to:
  /// **'\"{title}\" vinculada a {host}. Vuelva a abrir la extensión para rellenar.'**
  String linkDone(Object title, Object host);

  /// No description provided for @linkSaveFailed.
  ///
  /// In es, this message translates to:
  /// **'No se pudo guardar el vínculo.'**
  String get linkSaveFailed;

  /// No description provided for @browserLoginSaved.
  ///
  /// In es, this message translates to:
  /// **'Se guardó la contraseña de {site}.'**
  String browserLoginSaved(String site);

  /// No description provided for @browserLoginSaveFailed.
  ///
  /// In es, this message translates to:
  /// **'No se pudo guardar la contraseña de {site}.'**
  String browserLoginSaveFailed(String site);

  /// No description provided for @browserNeverSaveTitle.
  ///
  /// In es, this message translates to:
  /// **'Sitios donde no se ofrece guardar contraseñas'**
  String get browserNeverSaveTitle;

  /// No description provided for @browserNeverSaveRemove.
  ///
  /// In es, this message translates to:
  /// **'Volver a ofrecer en {site}'**
  String browserNeverSaveRemove(String site);

  /// No description provided for @navVault.
  ///
  /// In es, this message translates to:
  /// **'Bóveda'**
  String get navVault;

  /// No description provided for @settingsTitle.
  ///
  /// In es, this message translates to:
  /// **'Ajustes'**
  String get settingsTitle;

  /// No description provided for @settingsAppearanceHint.
  ///
  /// In es, this message translates to:
  /// **'Idioma, tema e íconos de los sitios'**
  String get settingsAppearanceHint;

  /// No description provided for @settingsImportHint.
  ///
  /// In es, this message translates to:
  /// **'Desde SafeInCloud, Bitwarden, Chrome, KeePassXC o un respaldo de Lockspire'**
  String get settingsImportHint;

  /// No description provided for @settingsExportHint.
  ///
  /// In es, this message translates to:
  /// **'Respaldo cifrado, o CSV/JSON para otro gestor'**
  String get settingsExportHint;

  /// No description provided for @settingsBrowserHint.
  ///
  /// In es, this message translates to:
  /// **'Conectar con la extensión de Chrome/Edge'**
  String get settingsBrowserHint;

  /// No description provided for @aboutTitle.
  ///
  /// In es, this message translates to:
  /// **'Acerca de'**
  String get aboutTitle;

  /// No description provided for @settingsAboutHint.
  ///
  /// In es, this message translates to:
  /// **'Versión, licencia y código fuente'**
  String get settingsAboutHint;

  /// No description provided for @settingsGeneral.
  ///
  /// In es, this message translates to:
  /// **'General'**
  String get settingsGeneral;

  /// No description provided for @settingsIntegrations.
  ///
  /// In es, this message translates to:
  /// **'Integraciones'**
  String get settingsIntegrations;

  /// No description provided for @settingsData.
  ///
  /// In es, this message translates to:
  /// **'Datos'**
  String get settingsData;

  /// No description provided for @settingsAutofillHint.
  ///
  /// In es, this message translates to:
  /// **'Rellenar sus contraseñas en otras apps'**
  String get settingsAutofillHint;

  /// No description provided for @securityMasterPasswordSection.
  ///
  /// In es, this message translates to:
  /// **'Contraseña maestra'**
  String get securityMasterPasswordSection;

  /// No description provided for @securityUnlockSection.
  ///
  /// In es, this message translates to:
  /// **'Desbloqueo'**
  String get securityUnlockSection;

  /// No description provided for @trayOpen.
  ///
  /// In es, this message translates to:
  /// **'Abrir Lockspire'**
  String get trayOpen;

  /// No description provided for @trayQuit.
  ///
  /// In es, this message translates to:
  /// **'Salir'**
  String get trayQuit;

  /// No description provided for @trayStillOpenTitle.
  ///
  /// In es, this message translates to:
  /// **'Lockspire sigue abierto'**
  String get trayStillOpenTitle;

  /// No description provided for @trayStillOpenBody.
  ///
  /// In es, this message translates to:
  /// **'Al cerrar la ventana, Lockspire queda en la bandeja del sistema para que la extensión del navegador pueda autocompletar. La bóveda se bloquea sola tras el tiempo sin uso que elija en Seguridad, al bloquear la sesión o al suspender el equipo.\n\nPara cerrarlo del todo, use \"Salir\" en el icono de la bandeja.'**
  String get trayStillOpenBody;

  /// No description provided for @aboutOpenFailed.
  ///
  /// In es, this message translates to:
  /// **'No se pudo abrir {url}'**
  String aboutOpenFailed(Object url);

  /// No description provided for @aboutVersion.
  ///
  /// In es, this message translates to:
  /// **'Versión {version} ({build})'**
  String aboutVersion(Object version, Object build);

  /// No description provided for @aboutTagline.
  ///
  /// In es, this message translates to:
  /// **'Gestor de contraseñas libre y local. Su bóveda se cifra en su dispositivo y solo se sincroniza con la nube que usted elija. Sin publicidad, sin analíticas y sin servidores propios.'**
  String get aboutTagline;

  /// No description provided for @aboutDevelopedBy.
  ///
  /// In es, this message translates to:
  /// **'Desarrollado por'**
  String get aboutDevelopedBy;

  /// No description provided for @aboutAuthorLine.
  ///
  /// In es, this message translates to:
  /// **'Ingeniero de sistemas y desarrollador backend, con formación en desarrollo de software seguro (CSSLP, OWASP Top 10).'**
  String get aboutAuthorLine;

  /// No description provided for @aboutSourceCode.
  ///
  /// In es, this message translates to:
  /// **'Código fuente'**
  String get aboutSourceCode;

  /// No description provided for @aboutLicense.
  ///
  /// In es, this message translates to:
  /// **'Licencia'**
  String get aboutLicense;

  /// No description provided for @aboutLicenseName.
  ///
  /// In es, this message translates to:
  /// **'GNU Affero General Public License v3 o posterior'**
  String get aboutLicenseName;

  /// No description provided for @aboutPrivacyPolicy.
  ///
  /// In es, this message translates to:
  /// **'Política de privacidad'**
  String get aboutPrivacyPolicy;

  /// No description provided for @aboutThirdParty.
  ///
  /// In es, this message translates to:
  /// **'Licencias de terceros'**
  String get aboutThirdParty;

  /// No description provided for @aboutThirdPartyHint.
  ///
  /// In es, this message translates to:
  /// **'Componentes de código abierto que usa Lockspire'**
  String get aboutThirdPartyHint;

  /// No description provided for @aboutLegalese.
  ///
  /// In es, this message translates to:
  /// **'Copyright (C) 2026 {author}. Distribuido bajo la GNU AGPL v3 o posterior.'**
  String aboutLegalese(Object author);

  /// No description provided for @aboutDonateTitle.
  ///
  /// In es, this message translates to:
  /// **'Invíteme un café'**
  String get aboutDonateTitle;

  /// No description provided for @aboutDonateBody.
  ///
  /// In es, this message translates to:
  /// **'Lockspire es gratis, sin publicidad y de código abierto. Si le resulta útil, puede apoyar su desarrollo con una donación.'**
  String get aboutDonateBody;

  /// No description provided for @aboutDonateCoffee.
  ///
  /// In es, this message translates to:
  /// **'Un café'**
  String get aboutDonateCoffee;

  /// No description provided for @aboutDonateCoffeeAndCake.
  ///
  /// In es, this message translates to:
  /// **'Café y pastel'**
  String get aboutDonateCoffeeAndCake;

  /// No description provided for @aboutDonateLunch.
  ///
  /// In es, this message translates to:
  /// **'Un almuerzo'**
  String get aboutDonateLunch;

  /// No description provided for @aboutDonateThanks.
  ///
  /// In es, this message translates to:
  /// **'¡Gracias por su apoyo!'**
  String get aboutDonateThanks;

  /// No description provided for @aboutDonatePending.
  ///
  /// In es, this message translates to:
  /// **'Su pago quedó pendiente. ¡Gracias por su apoyo!'**
  String get aboutDonatePending;

  /// No description provided for @aboutDonateFailed.
  ///
  /// In es, this message translates to:
  /// **'No se pudo completar la donación. Inténtelo de nuevo más tarde.'**
  String get aboutDonateFailed;

  /// No description provided for @autofillWrongSiteTitle.
  ///
  /// In es, this message translates to:
  /// **'¿Es el sitio correcto?'**
  String get autofillWrongSiteTitle;

  /// No description provided for @autofillWrongSiteBody.
  ///
  /// In es, this message translates to:
  /// **'\"{title}\" es de {entrySite}, pero la página que la pide es {pageHost}.\n\nSi no esperaba este sitio, puede ser una página falsa que intenta robar su contraseña (phishing).'**
  String autofillWrongSiteBody(Object title, Object entrySite, Object pageHost);

  /// No description provided for @autofillFillAnyway.
  ///
  /// In es, this message translates to:
  /// **'Rellenar igual'**
  String get autofillFillAnyway;

  /// No description provided for @autofillNoSiteTitle.
  ///
  /// In es, this message translates to:
  /// **'Esta entrada no tiene sitio'**
  String get autofillNoSiteTitle;

  /// No description provided for @autofillNoSiteBody.
  ///
  /// In es, this message translates to:
  /// **'\"{title}\" no tiene un sitio guardado, así que Lockspire no puede comprobar que {host} sea el correcto.\n\nSi lo recuerda, la próxima vez se va a rellenar sola, y solo en este sitio.'**
  String autofillNoSiteBody(Object title, Object host);

  /// No description provided for @autofillJustOnce.
  ///
  /// In es, this message translates to:
  /// **'Solo esta vez'**
  String get autofillJustOnce;

  /// No description provided for @autofillFillAndRemember.
  ///
  /// In es, this message translates to:
  /// **'Rellenar y recordar'**
  String get autofillFillAndRemember;

  /// No description provided for @autofillSearchHint.
  ///
  /// In es, this message translates to:
  /// **'Buscar por título'**
  String get autofillSearchHint;

  /// No description provided for @autofillEmpty.
  ///
  /// In es, this message translates to:
  /// **'Todavía no ha guardado ninguna contraseña en Lockspire.'**
  String get autofillEmpty;

  /// No description provided for @autofillNoResults.
  ///
  /// In es, this message translates to:
  /// **'No se encontraron resultados.'**
  String get autofillNoResults;

  /// No description provided for @autofillMatchesSite.
  ///
  /// In es, this message translates to:
  /// **'Coincide con el sitio'**
  String get autofillMatchesSite;

  /// No description provided for @autofillSavePrompt.
  ///
  /// In es, this message translates to:
  /// **'¿Guardar esta credencial en Lockspire?'**
  String get autofillSavePrompt;

  /// No description provided for @autofillNoThanks.
  ///
  /// In es, this message translates to:
  /// **'No, gracias'**
  String get autofillNoThanks;

  /// No description provided for @autofillBadRequest.
  ///
  /// In es, this message translates to:
  /// **'No se pudo entender el pedido de autocompletado.'**
  String get autofillBadRequest;

  /// No description provided for @autofillNoVault.
  ///
  /// In es, this message translates to:
  /// **'Todavía no ha creado una bóveda en Lockspire.'**
  String get autofillNoVault;

  /// No description provided for @commonClose.
  ///
  /// In es, this message translates to:
  /// **'Cerrar'**
  String get commonClose;

  /// No description provided for @autofillAndroidApp.
  ///
  /// In es, this message translates to:
  /// **'App de Android'**
  String get autofillAndroidApp;

  /// No description provided for @autofillUnknownApp.
  ///
  /// In es, this message translates to:
  /// **'App desconocida'**
  String get autofillUnknownApp;

  /// No description provided for @autofillInBrowser.
  ///
  /// In es, this message translates to:
  /// **'en {browser}'**
  String autofillInBrowser(Object browser);

  /// No description provided for @autofillInUnknownApp.
  ///
  /// In es, this message translates to:
  /// **'en una app desconocida'**
  String get autofillInUnknownApp;

  /// No description provided for @autofillInsideApp.
  ///
  /// In es, this message translates to:
  /// **'dentro de la app {package}'**
  String autofillInsideApp(Object package);

  /// No description provided for @biometricPromptReason.
  ///
  /// In es, this message translates to:
  /// **'Verifíquese para desbloquear Lockspire'**
  String get biometricPromptReason;

  /// No description provided for @errorProfileNameEmpty.
  ///
  /// In es, this message translates to:
  /// **'Escriba un nombre para el perfil.'**
  String get errorProfileNameEmpty;

  /// No description provided for @errorProfileNameTooLong.
  ///
  /// In es, this message translates to:
  /// **'El nombre puede tener hasta 30 caracteres.'**
  String get errorProfileNameTooLong;

  /// No description provided for @errorProfileNameTaken.
  ///
  /// In es, this message translates to:
  /// **'Ya hay un perfil con ese nombre.'**
  String get errorProfileNameTaken;

  /// No description provided for @errorProfileMainNotRemovable.
  ///
  /// In es, this message translates to:
  /// **'El perfil principal no se puede borrar.'**
  String get errorProfileMainNotRemovable;

  /// No description provided for @errorProfilesInUse.
  ///
  /// In es, this message translates to:
  /// **'Para desactivar los perfiles, primero borre los demás: solo puede quedar uno.'**
  String get errorProfilesInUse;

  /// No description provided for @profilesTitle.
  ///
  /// In es, this message translates to:
  /// **'Perfiles'**
  String get profilesTitle;

  /// No description provided for @profilesSubtitle.
  ///
  /// In es, this message translates to:
  /// **'Varias bóvedas en este dispositivo'**
  String get profilesSubtitle;

  /// No description provided for @profilesIntro.
  ///
  /// In es, this message translates to:
  /// **'Cada perfil tiene su propia bóveda, con su propia contraseña maestra, y sus propios ajustes: nube, huella, bloqueo, tema e idioma. Úselos si otra persona usa Lockspire en este dispositivo.'**
  String get profilesIntro;

  /// No description provided for @profilesEnable.
  ///
  /// In es, this message translates to:
  /// **'Usar varios perfiles'**
  String get profilesEnable;

  /// No description provided for @profilesEnableHint.
  ///
  /// In es, this message translates to:
  /// **'Vienen desactivados porque es raro compartir el teléfono.'**
  String get profilesEnableHint;

  /// No description provided for @profilesMainName.
  ///
  /// In es, this message translates to:
  /// **'Principal'**
  String get profilesMainName;

  /// No description provided for @profilesInUse.
  ///
  /// In es, this message translates to:
  /// **'En uso'**
  String get profilesInUse;

  /// No description provided for @profilesAdd.
  ///
  /// In es, this message translates to:
  /// **'Agregar perfil'**
  String get profilesAdd;

  /// No description provided for @profilesAddTitle.
  ///
  /// In es, this message translates to:
  /// **'Nuevo perfil'**
  String get profilesAddTitle;

  /// No description provided for @profilesAddBody.
  ///
  /// In es, this message translates to:
  /// **'Se abrirá vacío: ahí podrá crear su bóveda o restaurarla desde la nube.'**
  String get profilesAddBody;

  /// No description provided for @profilesNameLabel.
  ///
  /// In es, this message translates to:
  /// **'Nombre'**
  String get profilesNameLabel;

  /// No description provided for @profilesRename.
  ///
  /// In es, this message translates to:
  /// **'Cambiar nombre'**
  String get profilesRename;

  /// No description provided for @profilesRenameTitle.
  ///
  /// In es, this message translates to:
  /// **'Nombre del perfil'**
  String get profilesRenameTitle;

  /// No description provided for @profilesDelete.
  ///
  /// In es, this message translates to:
  /// **'Eliminar este perfil'**
  String get profilesDelete;

  /// No description provided for @profilesDeleteTitle.
  ///
  /// In es, this message translates to:
  /// **'¿Eliminar el perfil {name}?'**
  String profilesDeleteTitle(String name);

  /// No description provided for @profilesDeleteBody.
  ///
  /// In es, this message translates to:
  /// **'Se eliminan de este dispositivo su bóveda y sus ajustes. Lo que haya sincronizado en la nube no se toca. No se puede deshacer.'**
  String get profilesDeleteBody;

  /// No description provided for @profilesSwitch.
  ///
  /// In es, this message translates to:
  /// **'Abrir'**
  String get profilesSwitch;

  /// No description provided for @profilesPickerLabel.
  ///
  /// In es, this message translates to:
  /// **'Perfil'**
  String get profilesPickerLabel;

  /// No description provided for @profilesOpening.
  ///
  /// In es, this message translates to:
  /// **'Abriendo el perfil…'**
  String get profilesOpening;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'es'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'es':
      return AppLocalizationsEs();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
