// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Spanish Castilian (`es`).
class AppLocalizationsEs extends AppLocalizations {
  AppLocalizationsEs([String locale = 'es']) : super(locale);

  @override
  String get appTitle => 'Lockspire';

  @override
  String get appearanceTitle => 'Apariencia';

  @override
  String get appearanceMode => 'Modo';

  @override
  String get appearanceModeSystem => 'Sistema';

  @override
  String get appearanceModeLight => 'Claro';

  @override
  String get appearanceModeDark => 'Oscuro';

  @override
  String get appearanceModeSystemHint =>
      'Cambia sola entre claro y oscuro según su sistema.';

  @override
  String get appearanceTheme => 'Tema';

  @override
  String get appearanceLauncherIconNote =>
      'El ícono de Lockspire en el teléfono también cambia al tema elegido, en unos segundos. Algunos lanzadores quitan el acceso directo de la pantalla de inicio al cambiarlo: vuelva a agregarlo desde la lista de apps.';

  @override
  String get themeSystemColors => 'Colores del sistema';

  @override
  String get themeSystemUnavailable =>
      'No disponible en este equipo: se usa Lineage.';

  @override
  String get themeSystemAndroid =>
      'Material You: colores de su fondo de pantalla.';

  @override
  String get themeSystemDesktop => 'Color de acento del sistema.';

  @override
  String appearanceThemeSemantics(Object title) {
    return 'Tema $title';
  }

  @override
  String get appearanceInUse => 'En uso';

  @override
  String get appearanceLanguage => 'Idioma';

  @override
  String syncConnectFailed(Object provider, Object error) {
    return 'No se pudo conectar con $provider: $error';
  }

  @override
  String syncMoveTitle(Object target) {
    return '¿Mudar la bóveda a $target?';
  }

  @override
  String syncMoveBody(Object home, Object target) {
    return 'Su bóveda se sincroniza con $home. Si continúa, pasa a sincronizarse con $target y se deja un aviso en $home.\n\nSus otros dispositivos van a recibir ese aviso la próxima vez que sincronicen, y tendrán que conectar $target para seguir. No se pierde nada: lo que esté en $target se fusiona con esta bóveda.';
  }

  @override
  String get commonCancel => 'Cancelar';

  @override
  String get syncMoveConfirm => 'Mudar';

  @override
  String get syncReplaceRemoteTitle => '¿Reemplazar la copia de la nube?';

  @override
  String get syncReplaceRemoteBody =>
      'La nube tiene una versión más vieja que la de este dispositivo. Si restauró una copia antigua a propósito, puede reemplazarla con la de este dispositivo: no pierde nada que tenga aquí.\n\nSi no fue usted, alguien pudo haber accedido a su cuenta de la nube: cambie esa contraseña antes de seguir.';

  @override
  String get syncReplaceConfirm => 'Reemplazar';

  @override
  String get syncResultUploaded => 'Se subió la bóveda al servidor.';

  @override
  String get syncResultDownloaded => 'Se bajó la bóveda del servidor.';

  @override
  String get syncResultUpToDate => 'Ya estaba al día — nada que hacer.';

  @override
  String syncResultMergedFields(int fieldConflictsResolved) {
    String _temp0 = intl.Intl.pluralLogic(
      fieldConflictsResolved,
      locale: localeName,
      other: '$fieldConflictsResolved campos se resolvieron automáticamente',
      one: '1 campo se resolvió automáticamente',
    );
    return 'Se fusionaron los cambios: $_temp0 (puede ver el valor anterior en el historial de esa entrada).';
  }

  @override
  String syncResultMergedEntries(int autoResolvedCount) {
    String _temp0 = intl.Intl.pluralLogic(
      autoResolvedCount,
      locale: localeName,
      other: '$autoResolvedCount entradas resueltas automáticamente',
      one: '1 entrada resuelta automáticamente',
    );
    return 'Se fusionaron los cambios: $_temp0.';
  }

  @override
  String get syncResultMerged => 'Se fusionaron los cambios.';

  @override
  String syncResultMoved(Object provider) {
    return 'Su bóveda se mudó a $provider. Conéctela arriba para seguir sincronizando.';
  }

  @override
  String get syncWebdavUrl => 'URL del servidor WebDAV';

  @override
  String get syncWebdavUrlRequired => 'Ingrese la URL del servidor';

  @override
  String get syncWebdavHttpsRequired =>
      'Use https://: con http:// su usuario y contraseña del servidor viajarían sin cifrar.';

  @override
  String get syncWebdavUrlInvalid =>
      'Ingrese una URL completa, p. ej. https://servidor/dav';

  @override
  String get syncWebdavUser => 'Usuario';

  @override
  String get syncWebdavUserRequired => 'Ingrese el usuario';

  @override
  String get syncWebdavPassword => 'Contraseña';

  @override
  String get syncWebdavPasswordUnchanged => '(sin cambios si se deja vacío)';

  @override
  String get syncWebdavPasswordRequired => 'Ingrese la contraseña';

  @override
  String get commonSave => 'Guardar';

  @override
  String get syncTitle => 'Sincronización';

  @override
  String get syncGoogleScopeNote =>
      'Lockspire solo accede a su propia carpeta oculta de datos en su Drive: no ve el resto de sus archivos.';

  @override
  String get syncConnectGoogle => 'Conectar con Google';

  @override
  String get syncOneDriveScopeNote =>
      'Lockspire solo accede a su propia carpeta especial de app en su OneDrive: no ve el resto de sus archivos.';

  @override
  String get syncConnectOneDrive => 'Conectar con OneDrive';

  @override
  String commonErrorDetail(Object error) {
    return 'Ocurrió un error: $error';
  }

  @override
  String get syncNow => 'Sincronizar ahora';

  @override
  String syncFailed(Object error) {
    return 'No se pudo sincronizar: $error';
  }

  @override
  String get syncUploadLocal => 'Subir la versión de este dispositivo';

  @override
  String get restoreNoProvider => 'Configure un proveedor de sync primero.';

  @override
  String restoreSearchFailed(Object error) {
    return 'No se pudo buscar la bóveda remota: $error';
  }

  @override
  String get restoreTitle => 'Restaurar bóveda existente';

  @override
  String get restoreIntro =>
      'Conecte el mismo proveedor de sync que ya usa en su otro dispositivo: vamos a bajar su bóveda desde ahí.';

  @override
  String get restoreSetUpProvider => 'Configurar proveedor de sync';

  @override
  String get restoreFindVault => 'Buscar mi bóveda';

  @override
  String get restoreSearching => 'Buscando su bóveda…';

  @override
  String get restoreSearchingDetail =>
      'Revisando el proveedor de sync configurado.';

  @override
  String get restoreNotFoundTitle => 'No hay ninguna bóveda ahí todavía';

  @override
  String get restoreNotFoundBody =>
      'El proveedor está conectado, pero no encontramos ninguna bóveda subida. Si el otro dispositivo todavía no sincronizó, pruebe desde ahí primero.';

  @override
  String get commonBack => 'Volver';

  @override
  String get restoreFoundTitle => 'Encontramos su bóveda';

  @override
  String get restoreFoundBody =>
      'Ingrese su contraseña maestra para desbloquearla.';

  @override
  String get commonMasterPassword => 'Contraseña maestra';

  @override
  String get commonMasterPasswordRequired => 'Ingrese su contraseña maestra';

  @override
  String get commonWrongPassword => 'Contraseña incorrecta';

  @override
  String get restoreConfirm => 'Restaurar bóveda';

  @override
  String cloudNotConnected(Object scopeNote) {
    return 'Sin cuenta conectada. $scopeNote';
  }

  @override
  String cloudConnectedAs(Object email) {
    return 'Conectado como $email';
  }

  @override
  String get cloudDisconnect => 'Desconectar';

  @override
  String get pwChangedBanner =>
      'La contraseña maestra se cambió en otro dispositivo. Ingrese la nueva para seguir sincronizando.';

  @override
  String get pwChangedEnterNew => 'Ingresar contraseña nueva';

  @override
  String get pwChangedNotNew => 'No es la contraseña nueva';

  @override
  String commonCouldNotComplete(Object error) {
    return 'No se pudo completar: $error';
  }

  @override
  String get pwChangedDialogTitle => 'Contraseña maestra nueva';

  @override
  String get pwChangedDialogBody =>
      'Ingrese la contraseña que puso en el otro dispositivo. Los cambios que hizo aquí se conservan.';

  @override
  String get pwChangedNewPassword => 'Contraseña nueva';

  @override
  String get commonContinue => 'Continuar';

  @override
  String syncHomeMovedBanner(Object provider) {
    return 'Su bóveda se mudó a $provider. Conecte $provider en este dispositivo para seguir sincronizando.';
  }

  @override
  String get syncHomeGoToSync => 'Ir a Sincronización';

  @override
  String errorSyncHomeMismatch(Object home, Object active) {
    return 'Su bóveda se sincroniza con $home, pero este dispositivo está conectado a $active. Conecte $home en Sincronización para seguir.';
  }

  @override
  String get errorRemoteDifferentVault =>
      'La nube tiene una bóveda distinta a la suya. No se cambió nada en este dispositivo.';

  @override
  String get errorRemoteNotAuthentic =>
      'La bóveda de la nube no se pudo verificar (está dañada, fue modificada o usa otra contraseña). No se cambió nada en este dispositivo.';

  @override
  String get errorRemotePasswordChanged =>
      'La contraseña maestra se cambió en otro dispositivo. Ingrese la contraseña nueva para seguir sincronizando.';

  @override
  String get errorRemoteRollback =>
      'La nube tiene una versión más vieja que la que este dispositivo ya sincronizó: puede ser una copia antigua restaurada o una manipulación. No se cambió nada en este dispositivo.';

  @override
  String get errorIncorrectCurrentPassword =>
      'La contraseña actual no es correcta.';

  @override
  String get errorPreviousPasswordRequired =>
      'Este dispositivo tiene cambios sin sincronizar. Ingrese también la contraseña anterior para conservarlos.';

  @override
  String get errorIncorrectPreviousPassword =>
      'La contraseña anterior no es correcta.';

  @override
  String errorUnknownImportFormat(Object extension) {
    return 'Formato no reconocido: .$extension. Use un XML de SafeInCloud, un CSV, un JSON de Bitwarden o un respaldo .lockspire.';
  }

  @override
  String get errorVaultWriteConflict =>
      'La bóveda cambió en disco desde que se abrió y no se sobrescribió. Vuelva a abrirla antes de guardar de nuevo.';

  @override
  String get errorIncorrectBackupPassword =>
      'La contraseña no abre este respaldo. Es la contraseña maestra que tenía la bóveda cuando se hizo.';

  @override
  String errorUnsupportedVaultFormat(int version) {
    return 'Esta bóveda se creó con una versión más nueva de Lockspire (formato $version). Actualice la app para abrirla.';
  }

  @override
  String get errorUnsafeKdfParams =>
      'El archivo de bóveda pide parámetros de cifrado fuera de lo normal. Puede estar dañado o haber sido modificado; no se abrió.';

  @override
  String masterPasswordTooShort(int count) {
    return 'Use al menos $count caracteres';
  }

  @override
  String get masterPasswordTooRepetitive =>
      'Tiene demasiados caracteres repetidos';

  @override
  String get masterPasswordTooWeak =>
      'Es demasiado fácil de adivinar: sume palabras, mayúsculas, números o símbolos';

  @override
  String get errorVaultLocked => 'La bóveda tiene que estar desbloqueada.';

  @override
  String get errorNotAVaultFile =>
      'No es un archivo de bóveda de Lockspire válido.';

  @override
  String get errorSyncNotConfigured =>
      'Configure un proveedor de sync primero (WebDAV, Google Drive u OneDrive).';

  @override
  String get errorSyncNothingToSync =>
      'No hay bóveda ni en este dispositivo ni en la nube.';

  @override
  String errorSyncConnectFailed(Object provider) {
    return 'No se pudo conectar con $provider.';
  }

  @override
  String get errorSyncConnectVaultCloud =>
      'Conecte la nube de su bóveda en Sincronización.';

  @override
  String errorRemoteVaultMissing(Object provider) {
    return 'No hay bóveda en $provider todavía.';
  }

  @override
  String errorRemoteUploadFailed(Object provider) {
    return 'No se pudo subir la bóveda a $provider.';
  }

  @override
  String get errorWebdavInsecureUrl =>
      'El servidor WebDAV usa http:// sin cifrar. Cambie la URL a https:// en Sincronización.';

  @override
  String get errorWebdavInvalidUrl =>
      'La URL del servidor WebDAV no es válida.';

  @override
  String errorAccountEmailUnreadable(Object provider) {
    return 'No se pudo leer el email de la cuenta de $provider.';
  }

  @override
  String get errorOauthBrowserFailed =>
      'No se pudo abrir el navegador del sistema.';

  @override
  String errorOauthTimedOut(Object provider) {
    return 'Se agotó el tiempo para iniciar sesión en $provider. Pruebe de nuevo.';
  }

  @override
  String get errorOauthNoCode => 'No se recibió el código de autorización.';

  @override
  String get errorOauthLoginClosed =>
      'Se cerró la espera del inicio de sesión.';

  @override
  String errorOauthTokenFailed(Object detail) {
    return 'No se pudo obtener el acceso a OneDrive: $detail';
  }

  @override
  String errorOauthRefreshFailed(Object detail) {
    return 'No se pudo renovar la sesión de OneDrive: $detail';
  }

  @override
  String errorNativeHostMissing(Object path) {
    return 'No se encontró el componente de conexión con el navegador en $path. Reinstale Lockspire.';
  }

  @override
  String get errorNativeHostElevationCancelled =>
      'No se completó el registro para todo el equipo (¿se canceló el permiso de administrador?).';

  @override
  String get errorNativeHostWindowsOnly =>
      'Solo disponible en Windows por ahora.';

  @override
  String get errorNoSupportedBrowser =>
      'No se encontró ningún navegador compatible.';

  @override
  String get errorImportInvalidJson => 'El archivo no es un JSON válido.';

  @override
  String get errorImportNotBitwardenJson =>
      'No es un export JSON de Bitwarden.';

  @override
  String get errorImportBitwardenEncrypted =>
      'Este JSON de Bitwarden está cifrado. Expórtelo de nuevo eligiendo \"JSON\" (sin cifrar) para poder importarlo.';

  @override
  String get errorImportCsvUnclosedQuote => 'El CSV tiene comillas sin cerrar.';

  @override
  String get errorImportCsvEmpty => 'El CSV está vacío.';

  @override
  String get errorImportCsvNoPasswordColumn =>
      'No se encontró una columna de contraseña. Exporte desde su gestor en CSV (Bitwarden, Chrome, Firefox o KeePassXC).';

  @override
  String get biometricWindowsHello => 'Windows Hello';

  @override
  String get biometricFingerprint => 'la huella';

  @override
  String get crackTimeInstant => 'instantáneo';

  @override
  String crackTimeSeconds(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count segundos',
      one: '1 segundo',
    );
    return '$_temp0';
  }

  @override
  String crackTimeMinutes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count minutos',
      one: '1 minuto',
    );
    return '$_temp0';
  }

  @override
  String crackTimeHours(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count horas',
      one: '1 hora',
    );
    return '$_temp0';
  }

  @override
  String crackTimeDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count días',
      one: '1 día',
    );
    return '$_temp0';
  }

  @override
  String crackTimeMonths(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count meses',
      one: '1 mes',
    );
    return '$_temp0';
  }

  @override
  String crackTimeYears(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count años',
      one: '1 año',
    );
    return '$_temp0';
  }

  @override
  String crackTimeCenturies(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count siglos',
      one: '1 siglo',
    );
    return '$_temp0';
  }

  @override
  String get crackTimeMillionsOfYears => 'millones de años';

  @override
  String get unlockPreviousPasswordNeeded =>
      'Este dispositivo tiene cambios que aún no se sincronizaron. Para conservarlos, ingrese también la contraseña anterior.';

  @override
  String get unlockPreviousPasswordWrong =>
      'La contraseña anterior no es correcta';

  @override
  String get unlockWelcomeBack => '¡Hola de nuevo!';

  @override
  String get unlockPrompt => 'Ingrese su contraseña para entrar a su bóveda';

  @override
  String unlockPasswordChangedElsewhere(Object method) {
    return 'La contraseña maestra se cambió en otro dispositivo. Ingrese la nueva para entrar. Hasta entonces no se puede usar $method.';
  }

  @override
  String unlockPeriodicReminder(Object method) {
    return 'Por seguridad, cada tanto Lockspire le pide la contraseña maestra aunque use $method, para que no se le olvide. Después vuelve a funcionar como siempre.';
  }

  @override
  String get unlockPreviousPassword => 'Contraseña anterior';

  @override
  String get unlockPreviousPasswordRequired => 'Ingrese la contraseña anterior';

  @override
  String get unlockUnlocking =>
      'Desbloqueando… esto puede tardar unos segundos (derivación de clave Argon2id)';

  @override
  String get unlockButton => 'Desbloquear';

  @override
  String get unlockEnterNewPassword => 'Ingresar la contraseña nueva';

  @override
  String get unlockNoNewPassword => 'No tengo la contraseña nueva';

  @override
  String unlockUseBiometric(Object method) {
    return 'Usar $method';
  }

  @override
  String get createVaultTitle => 'Crear bóveda';

  @override
  String get createVaultHeading => 'Cree su bóveda';

  @override
  String get createVaultIntro =>
      'Elija una contraseña maestra. Nunca se envía ni se guarda: si la olvida, no hay forma de recuperarla.';

  @override
  String createVaultMinLength(int count) {
    return 'Mínimo $count caracteres';
  }

  @override
  String get createVaultPasswordRequired => 'Ingrese una contraseña';

  @override
  String get createVaultConfirm => 'Confirmar contraseña';

  @override
  String get createVaultMismatch => 'No coincide con la contraseña anterior';

  @override
  String get createVaultCreating =>
      'Creando bóveda… esto puede tardar unos segundos (derivación de clave Argon2id)';

  @override
  String createVaultFailed(Object error) {
    return 'No se pudo crear la bóveda: $error';
  }

  @override
  String get createVaultRestoreLink =>
      '¿Ya tiene una bóveda? Restaurarla desde la nube';

  @override
  String get changePwDone =>
      'Contraseña maestra cambiada. Sus otros dispositivos se la pedirán la próxima vez que sincronicen.';

  @override
  String get changePwCurrentWrong => 'La contraseña actual no es correcta';

  @override
  String get changePwConflict =>
      'La bóveda cambió mientras se guardaba. La nube ya tiene la contraseña nueva: sincronice y, cuando se la pida, ingrésela.';

  @override
  String changePwFailed(Object error) {
    return 'No se pudo cambiar la contraseña, así que sigue siendo la misma. $error';
  }

  @override
  String get changePwTitle => 'Cambiar contraseña maestra';

  @override
  String get changePwIntro =>
      'Si tiene sincronización, primero se sincroniza y la bóveda nueva se sube a la nube: hace falta conexión. Las copias viejas que alguien ya tenga siguen abriéndose con la contraseña anterior.';

  @override
  String get changePwCurrent => 'Contraseña actual';

  @override
  String get changePwCurrentRequired => 'Ingrese su contraseña actual';

  @override
  String changePwNewHelper(int count) {
    return 'Mínimo $count caracteres, difícil de adivinar';
  }

  @override
  String get changePwMustDiffer => 'Tiene que ser distinta de la actual';

  @override
  String get changePwConfirmNew => 'Confirmar contraseña nueva';

  @override
  String get changePwMismatch => 'No coincide con la contraseña nueva';

  @override
  String get changePwShowPasswords => 'Mostrar contraseñas';

  @override
  String get changePwButton => 'Cambiar contraseña';

  @override
  String get commonRetry => 'Reintentar';

  @override
  String get strengthWeak => 'Débil';

  @override
  String get strengthFair => 'Regular';

  @override
  String get strengthStrong => 'Segura';

  @override
  String strengthLabel(Object level, Object time) {
    return '$level — tiempo estimado para descifrarla: $time';
  }

  @override
  String get deleteEntriesBody =>
      'Se eliminan de la bóveda en este dispositivo y en los demás al sincronizar.';

  @override
  String get commonDelete => 'Eliminar';

  @override
  String biometricOptInTitle(Object methodName) {
    return '¿Activar desbloqueo con $methodName?';
  }

  @override
  String biometricOptInBody(Object methodName) {
    return 'En vez de escribir la contraseña maestra cada vez, podrá desbloquear la bóveda con $methodName. Puede cambiarlo después desde \"Seguridad\".';
  }

  @override
  String get commonNotNow => 'Ahora no';

  @override
  String get commonTurnOn => 'Activar';

  @override
  String get entryTypePassword => 'Contraseña';

  @override
  String get entryTypeCard => 'Tarjeta';

  @override
  String get entryTypeDocument => 'Documento';

  @override
  String get selectionCancel => 'Cancelar selección';

  @override
  String selectionCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count seleccionadas',
      one: '1 seleccionada',
    );
    return '$_temp0';
  }

  @override
  String get selectionClear => 'Quitar selección';

  @override
  String get selectionAll => 'Seleccionar todo';

  @override
  String get selectionDelete => 'Eliminar seleccionadas';

  @override
  String get selectionStart => 'Seleccionar';

  @override
  String get commonLock => 'Bloquear';

  @override
  String get vaultSearchHint => 'Buscar por título, usuario o sitio';

  @override
  String get commonAdd => 'Agregar';

  @override
  String get autofillSettingsOpenFailed => 'No se pudo abrir la configuración.';

  @override
  String get securityTitle => 'Seguridad';

  @override
  String get securityChangePwHint =>
      'Hágalo si cree que alguien pudo conocerla.';

  @override
  String securityUnlockWith(Object method) {
    return 'Desbloquear con $method';
  }

  @override
  String securityUnlockWithHint(Object method) {
    return 'Use $method en vez de escribir la contraseña maestra cada vez.';
  }

  @override
  String get autofillSettingsTitle => 'Autocompletado';

  @override
  String get autofillSettingsHint =>
      'Active Lockspire como servicio de autocompletado para que aparezca como opción al iniciar sesión en otras apps — incluye logins dentro de un navegador embebido (ej. WebView).';

  @override
  String get autofillSettingsButton => 'Activar como autocompletado';

  @override
  String securityBiometricNotSetUp(Object method) {
    return 'Este dispositivo no tiene $method configurado.';
  }

  @override
  String securityBiometricSetUpHint(Object method) {
    return 'Configure $method en los ajustes del sistema para poder activarlo aquí.';
  }

  @override
  String get securityBiometricUnavailable =>
      'No disponible en este dispositivo.';

  @override
  String get securityReminderTitle => 'Pedir la contraseña maestra cada';

  @override
  String securityReminderHint(Object method) {
    return 'Aunque use $method, pasado este tiempo Lockspire le pide la contraseña una vez, para que no se le olvide. Si la olvida, la bóveda no se puede recuperar.';
  }

  @override
  String get securityAutoLock => 'Bloqueo automático';

  @override
  String get securityAutoLock15Warning =>
      'Más cómodo, pero la bóveda queda abierta más tiempo si se aleja del equipo.';

  @override
  String get siteIconsTitle => 'Íconos de los sitios';

  @override
  String get siteIconsHint =>
      'Descarga el ícono de cada sitio guardado directamente del sitio, sin servicios de terceros, y lo guarda cifrado en su bóveda. Cada sitio ve una visita desde su conexión. Sin activarlo, se muestra la inicial.';

  @override
  String get siteIconsFallback => 'Completar los que falten con DuckDuckGo';

  @override
  String get siteIconsFallbackHint =>
      'Para los sitios que no ofrecen ícono, se lo pide a DuckDuckGo. DuckDuckGo recibe solo esos dominios, nunca sus usuarios ni contraseñas.';

  @override
  String get siteIconsRetry => 'Volver a buscar los que faltan';

  @override
  String get vaultNoResults => 'No se encontraron resultados';

  @override
  String get vaultEmpty => 'Todavía no ha guardado ninguna contraseña';

  @override
  String get vaultEmptyHint => 'Toque el botón \"+\" para agregar la primera';

  @override
  String get generatorRandom => 'Aleatoria';

  @override
  String get generatorMemorable => 'Fácil de recordar';

  @override
  String generatorLength(int count) {
    return '$count caracteres';
  }

  @override
  String deleteEntriesTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '¿Eliminar $count entradas?',
      one: '¿Eliminar 1 entrada?',
    );
    return '$_temp0';
  }

  @override
  String deleteEntriesDone(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Se eliminaron $count entradas',
      one: 'Se eliminó 1 entrada',
    );
    return '$_temp0';
  }

  @override
  String commonDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count días',
      one: '1 día',
    );
    return '$_temp0';
  }

  @override
  String commonMinutesShort(int count) {
    return '$count min';
  }

  @override
  String get securityAutoLockHintAndroid =>
      'La bóveda se bloquea sola cuando pasa este tiempo sin que use Lockspire. También se bloquea al salir de la app.';

  @override
  String get securityAutoLockHintDesktop =>
      'La bóveda se bloquea sola cuando pasa este tiempo sin que use Lockspire. También se bloquea al bloquear la sesión o suspender el equipo.';

  @override
  String entryConflict(Object error) {
    return '$error Revise los datos e intente guardar de nuevo.';
  }

  @override
  String entrySaveFailed(Object error) {
    return 'No se pudo guardar: $error';
  }

  @override
  String get entryDeleteTitle => '¿Eliminar esta entrada?';

  @override
  String entryDeleteBody(Object title) {
    return 'Se eliminará \"$title\" de la bóveda.';
  }

  @override
  String entryCopied(Object label, int seconds) {
    return 'Copiado: $label. Se borra en $seconds s o al bloquear';
  }

  @override
  String get fieldUsername => 'Usuario';

  @override
  String get fieldPassword => 'Contraseña';

  @override
  String get entryGeneratePassword => 'Generar contraseña';

  @override
  String get fieldTitle => 'Título';

  @override
  String get entryTitleRequired => 'Ingrese un título';

  @override
  String get entryWebsites => 'Sitios web';

  @override
  String get fieldWebsite => 'Sitio web';

  @override
  String get entryAddWebsite => 'Agregar sitio web';

  @override
  String get entryAndroidApps => 'Apps Android';

  @override
  String get entryAppPackage => 'App (paquete)';

  @override
  String get entryAddApp => 'Agregar app';

  @override
  String get entryOtherFields => 'Otros campos';

  @override
  String get entryAndroidApp => 'App Android';

  @override
  String get entryField => 'Campo';

  @override
  String get fieldNotes => 'Notas';

  @override
  String get entrySavedEncrypted =>
      'Se guarda cifrada junto con el resto de su bóveda.';

  @override
  String fieldCopy(Object field) {
    return 'Copiar $field';
  }

  @override
  String get commonShow => 'Mostrar';

  @override
  String get commonHide => 'Ocultar';

  @override
  String get commonRemove => 'Quitar';

  @override
  String get customFieldRemove => 'Quitar campo';

  @override
  String get customFieldAdd => 'Agregar campo';

  @override
  String get customFieldNameRequired => 'Ingrese un nombre';

  @override
  String get customFieldNameTaken => 'Ya hay un campo con ese nombre';

  @override
  String get customFieldNew => 'Nuevo campo';

  @override
  String get customFieldName => 'Nombre del campo';

  @override
  String get customFieldNameHint => 'Por ejemplo: Pregunta secreta';

  @override
  String get customFieldHidden => 'Ocultar el valor';

  @override
  String get customFieldHiddenHint =>
      'Para claves, PIN y otros datos sensibles';

  @override
  String get fieldCardNumber => 'Número de tarjeta';

  @override
  String get fieldCardHolder => 'Titular';

  @override
  String get fieldExpiry => 'Vence';

  @override
  String get fieldCardExpiryHint => 'MM/AA';

  @override
  String get fieldCvv => 'CVV';

  @override
  String get fieldPin => 'PIN';

  @override
  String get fieldDocNumber => 'Número';

  @override
  String get fieldDocName => 'Nombre';

  @override
  String get fieldBirthDate => 'Fecha de nacimiento';

  @override
  String get fieldIssued => 'Expedido';

  @override
  String get fieldDateHint => 'DD/MM/AAAA';

  @override
  String fieldWebsiteN(Object n) {
    return 'Sitio web $n';
  }

  @override
  String fieldAppN(Object n) {
    return 'App $n';
  }

  @override
  String get fieldGenerationMode => 'Modo de generación';

  @override
  String get fieldGenerationParam => 'Parámetro de generación';

  @override
  String get historyTitle => 'Valores anteriores';

  @override
  String get historyHint =>
      'Lo que tenían antes estos campos: al editarlos, al actualizarlos desde el navegador, al importar o al resolverse solo un cambio en otro dispositivo.';

  @override
  String get historyCopy => 'Copiar el valor anterior';

  @override
  String entryNewTitle(String type) {
    String _temp0 = intl.Intl.selectLogic(type, {
      'card': 'Nueva tarjeta',
      'document': 'Nuevo documento',
      'note': 'Nueva nota',
      'passkey': 'Nueva passkey',
      'other': 'Nueva contraseña',
    });
    return '$_temp0';
  }

  @override
  String entryEditTitle(String type) {
    String _temp0 = intl.Intl.selectLogic(type, {
      'card': 'Editar tarjeta',
      'document': 'Editar documento',
      'note': 'Editar nota',
      'passkey': 'Editar passkey',
      'other': 'Editar contraseña',
    });
    return '$_temp0';
  }

  @override
  String importReadFailed(Object error) {
    return 'No se pudo leer el archivo: $error';
  }

  @override
  String importConflict(Object error) {
    return '$error Vuelva a intentar importar.';
  }

  @override
  String importFailed(Object error) {
    return 'No se pudo importar: $error';
  }

  @override
  String get importDoneTitle => 'Importación completada';

  @override
  String importDoneUnencrypted(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Se importaron $count entradas',
      one: 'Se importó 1 entrada',
    );
    return '$_temp0. Por su seguridad: el archivo que eligió no está cifrado. Bórrelo del lugar donde lo guardó (y de la papelera): Lockspire no puede borrarlo por usted.';
  }

  @override
  String importDoneBackup(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Se importaron $count entradas',
      one: 'Se importó 1 entrada',
    );
    return '$_temp0 desde el respaldo.';
  }

  @override
  String get commonGotIt => 'Entendido';

  @override
  String get importTitle => 'Importar';

  @override
  String get importIntro =>
      'Elija el archivo que exportó desde su otro gestor, o un respaldo de Lockspire. Se lee directo en memoria, sin guardar ninguna copia, y nunca se duplican entradas que ya tiene.';

  @override
  String get importBitwardenDetail => 'CSV o JSON sin cifrar';

  @override
  String get importOthersSource => 'Chrome, Edge, Firefox, KeePassXC y otros';

  @override
  String get importLockspireBackup => 'Respaldo de Lockspire';

  @override
  String get importLockspireBackupDetail => '.lockspire, con su contraseña';

  @override
  String get importChooseFile => 'Elegir archivo';

  @override
  String get importNothingNew => 'No hay entradas nuevas';

  @override
  String importWillImport(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Se importarán $count entradas',
      one: 'Se importará 1 entrada',
    );
    return '$_temp0';
  }

  @override
  String importSkipped(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count ya estaban en su bóveda y se omiten',
      one: '1 ya estaba en su bóveda y se omite',
    );
    return '$_temp0';
  }

  @override
  String get importBackupPassword => 'Contraseña del respaldo';

  @override
  String get importBackupPasswordHint =>
      'Ingrese la contraseña maestra que tenía la bóveda cuando se hizo este respaldo.';

  @override
  String get commonOpen => 'Abrir';

  @override
  String get exportUnencryptedTitle => 'El archivo no va a estar cifrado';

  @override
  String get exportUnencryptedConfirm => 'Entiendo, exportar';

  @override
  String get exportWrongPassword => 'La contraseña maestra no es correcta';

  @override
  String get exportSaveDialogTitle => 'Guardar exportación';

  @override
  String exportFailed(Object error) {
    return 'No se pudo exportar: $error';
  }

  @override
  String get exportDoneTitle => 'Exportación lista';

  @override
  String get exportDoneBackup =>
      'Se guardó el respaldo cifrado. Para abrirlo hace falta la contraseña maestra actual; si la cambia después, este respaldo sigue pidiendo la de hoy.';

  @override
  String exportDoneFile(Object format) {
    return 'Se guardó el $format.';
  }

  @override
  String exportSkipped(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count tarjetas o documentos no se incluyeron',
      one: '1 tarjeta o documento no se incluyó',
    );
    return '$_temp0: este formato solo lleva contraseñas.';
  }

  @override
  String get exportDeleteReminder =>
      'Recuerde borrarlo, también de la papelera, en cuanto lo importe en el otro gestor.';

  @override
  String get exportTitle => 'Exportar';

  @override
  String get exportFormat => 'Formato';

  @override
  String get exportBackupLabel => 'Respaldo de Lockspire (cifrado)';

  @override
  String get exportBackupHint =>
      'Todo su contenido, cifrado con su contraseña maestra. Para guardarlo como respaldo o restaurarlo en otro Lockspire.';

  @override
  String get exportUnencryptedNote =>
      'Este formato no está cifrado. Úselo solo para pasar sus datos a otro gestor.';

  @override
  String get exportPasswordAlwaysAsked =>
      'Para exportar siempre se pide la contraseña.';

  @override
  String importCountPasswords(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count contraseñas',
      one: '1 contraseña',
    );
    return '$_temp0';
  }

  @override
  String importCountCards(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count tarjetas',
      one: '1 tarjeta',
    );
    return '$_temp0';
  }

  @override
  String importCountDocuments(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count documentos',
      one: '1 documento',
    );
    return '$_temp0';
  }

  @override
  String commonListAnd(Object first, Object last) {
    return '$first y $last';
  }

  @override
  String exportUnencryptedBodyPasswords(Object format) {
    return 'Cualquiera que abra el $format verá todas sus contraseñas. Guárdelo solo el tiempo necesario para importarlo en el otro gestor y después bórrelo, también de la papelera. No lo suba a la nube ni lo envíe por correo o chat.';
  }

  @override
  String exportUnencryptedBodyAll(Object format) {
    return 'Cualquiera que abra el $format verá todas sus contraseñas, tarjetas y documentos. Guárdelo solo el tiempo necesario para importarlo en el otro gestor y después bórrelo, también de la papelera. No lo suba a la nube ni lo envíe por correo o chat.';
  }

  @override
  String get exportBitwardenCsv => 'CSV de Bitwarden';

  @override
  String get exportBitwardenCsvHint =>
      'Sin cifrar. Lo aceptan Bitwarden, Proton Pass, 1Password, KeePassXC y otros. Tarjetas y documentos van como notas.';

  @override
  String get exportBitwardenJson => 'JSON de Bitwarden';

  @override
  String get exportBitwardenJsonHint =>
      'Sin cifrar. Incluye tarjetas y documentos. Lo leen Bitwarden y otros gestores que importan desde Bitwarden.';

  @override
  String get exportChromeCsv => 'CSV de Chrome';

  @override
  String get exportChromeCsvHint =>
      'Sin cifrar. El formato más simple: lo importan Chrome, Edge, Firefox y Google Password Manager. Solo contraseñas.';

  @override
  String get browserRegistered =>
      'Listo. Reinicie el navegador si ya estaba abierto.';

  @override
  String get browserUnregistered =>
      'Lockspire ya no está conectado a los navegadores.';

  @override
  String get browserRegisteredSystemWide =>
      'Listo para todo el equipo. Reinicie el navegador si ya estaba abierto.';

  @override
  String get browserUnregisteredSystemWide =>
      'Se quitó el registro para todo el equipo.';

  @override
  String get browserTitle => 'Navegador';

  @override
  String get browserIntro =>
      'Con la extensión de Lockspire para Chrome o Edge puede rellenar usuario y contraseña en los sitios web. La extensión le pide las credenciales a esta app; la bóveda nunca sale de acá y, si está bloqueada, la extensión le pide que la desbloquee primero.';

  @override
  String browserConnectedWith(Object browsers) {
    return 'Conectado con $browsers';
  }

  @override
  String get browserNotConnected => 'No conectado con ningún navegador';

  @override
  String get browserHostMissing =>
      'Falta el componente \"lockspire-native-host\" junto a la app. Ver native-host/README.md.';

  @override
  String get browserReconnect => 'Volver a conectar';

  @override
  String get browserConnect => 'Conectar con Chrome/Edge';

  @override
  String get browserSystemWide => 'Para todo el equipo';

  @override
  String get browserSystemWideHint =>
      'Si la extensión sigue diciendo que no está conectada, su organización puede estar bloqueando las conexiones por usuario (política \"NativeMessagingUserLevelHosts\" de Chrome, visible en chrome://policy). En ese caso, registre Lockspire para todo el equipo: Windows le va a pedir permisos de administrador.';

  @override
  String get browserSystemWideOn => 'Registrado para todo el equipo';

  @override
  String get browserSystemWideOff => 'No registrado para todo el equipo';

  @override
  String get browserReregister => 'Volver a registrar';

  @override
  String get browserRegisterSystemWide => 'Registrar para todo el equipo';

  @override
  String get browserRemoveRegistration => 'Quitar registro';

  @override
  String get browserInstallExtension => 'Instalar la extensión';

  @override
  String get browserInstallExtensionHint =>
      'Mientras no esté publicada en la Chrome Web Store: abra chrome://extensions (o edge://extensions), active \"Modo de desarrollador\", elija \"Cargar descomprimida\" y seleccione la carpeta extension/dist del proyecto.';

  @override
  String get bridgeRunning => 'Lockspire está escuchando a la extensión.';

  @override
  String get bridgeAnotherInstance =>
      'Otra instancia de Lockspire ya atiende a la extensión.';

  @override
  String get bridgeUnavailable =>
      'No se pudo abrir el canal con la extensión en este equipo.';

  @override
  String get bridgeUnsupported =>
      'La extensión de navegador solo funciona en escritorio.';

  @override
  String get commonStarting => 'Iniciando…';

  @override
  String get linkTitle => '¿Vincular este sitio?';

  @override
  String linkBody(Object title) {
    return 'La extensión pide usar \"$title\" en:';
  }

  @override
  String get linkNoUrl => 'La entrada no tenía ninguna URL.';

  @override
  String linkReplacesUrl(Object url) {
    return 'Reemplaza la URL actual: $url';
  }

  @override
  String get linkPhishingWarning =>
      'Compruebe que la dirección sea la real: si es un sitio falso que imita al original, le estaría dando esta contraseña.';

  @override
  String get linkConfirm => 'Vincular';

  @override
  String get linkEntryGone => 'La entrada ya no existe.';

  @override
  String linkDone(Object title, Object host) {
    return '\"$title\" vinculada a $host. Vuelva a abrir la extensión para rellenar.';
  }

  @override
  String get linkSaveFailed => 'No se pudo guardar el vínculo.';

  @override
  String browserLoginSaved(String site) {
    return 'Se guardó la contraseña de $site.';
  }

  @override
  String browserLoginSaveFailed(String site) {
    return 'No se pudo guardar la contraseña de $site.';
  }

  @override
  String get browserNeverSaveTitle =>
      'Sitios donde no se ofrece guardar contraseñas';

  @override
  String browserNeverSaveRemove(String site) {
    return 'Volver a ofrecer en $site';
  }

  @override
  String get navVault => 'Bóveda';

  @override
  String get settingsTitle => 'Ajustes';

  @override
  String get settingsAppearanceHint => 'Idioma, tema e íconos de los sitios';

  @override
  String get settingsImportHint =>
      'Desde SafeInCloud, Bitwarden, Chrome, KeePassXC o un respaldo de Lockspire';

  @override
  String get settingsExportHint =>
      'Respaldo cifrado, o CSV/JSON para otro gestor';

  @override
  String get settingsBrowserHint => 'Conectar con la extensión de Chrome/Edge';

  @override
  String get aboutTitle => 'Acerca de';

  @override
  String get settingsAboutHint => 'Versión, licencia y código fuente';

  @override
  String get settingsGeneral => 'General';

  @override
  String get settingsIntegrations => 'Integraciones';

  @override
  String get settingsData => 'Datos';

  @override
  String get settingsAutofillHint => 'Rellenar sus contraseñas en otras apps';

  @override
  String get securityMasterPasswordSection => 'Contraseña maestra';

  @override
  String get securityUnlockSection => 'Desbloqueo';

  @override
  String get trayOpen => 'Abrir Lockspire';

  @override
  String get trayQuit => 'Salir';

  @override
  String get trayStillOpenTitle => 'Lockspire sigue abierto';

  @override
  String get trayStillOpenBody =>
      'Al cerrar la ventana, Lockspire queda en la bandeja del sistema para que la extensión del navegador pueda autocompletar. La bóveda se bloquea sola tras el tiempo sin uso que elija en Seguridad, al bloquear la sesión o al suspender el equipo.\n\nPara cerrarlo del todo, use \"Salir\" en el icono de la bandeja.';

  @override
  String aboutOpenFailed(Object url) {
    return 'No se pudo abrir $url';
  }

  @override
  String aboutVersion(Object version, Object build) {
    return 'Versión $version ($build)';
  }

  @override
  String get aboutTagline =>
      'Gestor de contraseñas libre y local. Su bóveda se cifra en su dispositivo y solo se sincroniza con la nube que usted elija. Sin publicidad, sin analíticas y sin servidores propios.';

  @override
  String get aboutDevelopedBy => 'Desarrollado por';

  @override
  String get aboutAuthorLine =>
      'Ingeniero de sistemas y desarrollador backend, con formación en desarrollo de software seguro (CSSLP, OWASP Top 10).';

  @override
  String get aboutSourceCode => 'Código fuente';

  @override
  String get aboutLicense => 'Licencia';

  @override
  String get aboutLicenseName =>
      'GNU Affero General Public License v3 o posterior';

  @override
  String get aboutPrivacyPolicy => 'Política de privacidad';

  @override
  String get aboutThirdParty => 'Licencias de terceros';

  @override
  String get aboutThirdPartyHint =>
      'Componentes de código abierto que usa Lockspire';

  @override
  String aboutLegalese(Object author) {
    return 'Copyright (C) 2026 $author. Distribuido bajo la GNU AGPL v3 o posterior.';
  }

  @override
  String get aboutDonateTitle => 'Invíteme un café';

  @override
  String get aboutDonateBody =>
      'Lockspire es gratis, sin publicidad y de código abierto. Si le resulta útil, puede apoyar su desarrollo con una donación.';

  @override
  String get aboutDonateCoffee => 'Un café';

  @override
  String get aboutDonateCoffeeAndCake => 'Café y pastel';

  @override
  String get aboutDonateLunch => 'Un almuerzo';

  @override
  String get aboutDonateThanks => '¡Gracias por su apoyo!';

  @override
  String get aboutDonatePending =>
      'Su pago quedó pendiente. ¡Gracias por su apoyo!';

  @override
  String get aboutDonateFailed =>
      'No se pudo completar la donación. Inténtelo de nuevo más tarde.';

  @override
  String get autofillWrongSiteTitle => '¿Es el sitio correcto?';

  @override
  String autofillWrongSiteBody(
    Object title,
    Object entrySite,
    Object pageHost,
  ) {
    return '\"$title\" es de $entrySite, pero la página que la pide es $pageHost.\n\nSi no esperaba este sitio, puede ser una página falsa que intenta robar su contraseña (phishing).';
  }

  @override
  String get autofillFillAnyway => 'Rellenar igual';

  @override
  String get autofillNoSiteTitle => 'Esta entrada no tiene sitio';

  @override
  String autofillNoSiteBody(Object title, Object host) {
    return '\"$title\" no tiene un sitio guardado, así que Lockspire no puede comprobar que $host sea el correcto.\n\nSi lo recuerda, la próxima vez se va a rellenar sola, y solo en este sitio.';
  }

  @override
  String get autofillJustOnce => 'Solo esta vez';

  @override
  String get autofillFillAndRemember => 'Rellenar y recordar';

  @override
  String get autofillSearchHint => 'Buscar por título';

  @override
  String get autofillEmpty =>
      'Todavía no ha guardado ninguna contraseña en Lockspire.';

  @override
  String get autofillNoResults => 'No se encontraron resultados.';

  @override
  String get autofillMatchesSite => 'Coincide con el sitio';

  @override
  String get autofillSavePrompt => '¿Guardar esta credencial en Lockspire?';

  @override
  String get autofillNoThanks => 'No, gracias';

  @override
  String get autofillBadRequest =>
      'No se pudo entender el pedido de autocompletado.';

  @override
  String get autofillNoVault => 'Todavía no ha creado una bóveda en Lockspire.';

  @override
  String get commonClose => 'Cerrar';

  @override
  String get autofillAndroidApp => 'App de Android';

  @override
  String get autofillUnknownApp => 'App desconocida';

  @override
  String autofillInBrowser(Object browser) {
    return 'en $browser';
  }

  @override
  String get autofillInUnknownApp => 'en una app desconocida';

  @override
  String autofillInsideApp(Object package) {
    return 'dentro de la app $package';
  }

  @override
  String get biometricPromptReason => 'Verifíquese para desbloquear Lockspire';
}
