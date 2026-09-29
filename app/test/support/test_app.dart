// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Gabriel Ángel Montoya Rico

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lockspire/app_composition.dart';
import 'package:lockspire/features/about/presentation/providers/about_providers.dart';
import 'package:lockspire/features/appearance/presentation/launcher_icon_sync.dart';
import 'package:lockspire/features/appearance/presentation/providers/system_accent_color_provider.dart';
import 'package:lockspire/features/autofill/domain/ports/autofill_host_port.dart';
import 'package:lockspire/features/autofill/presentation/autofill_app.dart';
import 'package:lockspire/features/autofill/presentation/providers/autofill_host_port_provider.dart';
import 'package:lockspire/features/autofill/presentation/providers/system_autofill_settings_port_provider.dart';
import 'package:lockspire/features/browser_bridge/presentation/providers/browser_bridge_provider.dart';
import 'package:lockspire/features/browser_bridge/presentation/providers/native_messaging_registration_port_provider.dart';
import 'package:lockspire/features/clipboard/presentation/providers/clipboard_guard_provider.dart';
import 'package:lockspire/features/desktop/presentation/providers/desktop_ports_providers.dart';
import 'package:lockspire/features/desktop/presentation/providers/is_desktop_shell_provider.dart';
import 'package:lockspire/features/desktop/presentation/providers/os_session_events_port_provider.dart';
import 'package:lockspire/features/sync/domain/ports/active_sync_provider_port.dart';
import 'package:lockspire/features/sync/presentation/providers/active_sync_port_provider.dart';
import 'package:lockspire/features/sync/presentation/providers/sync_ancestor_storage_port_provider.dart';
import 'package:lockspire/features/vault/domain/ports/biometric_auth_port.dart';
import 'package:lockspire/features/vault/presentation/providers/biometric_auth_port_provider.dart';
import 'package:lockspire/features/vault/presentation/providers/crypto_port_provider.dart';
import 'package:lockspire/features/vault/presentation/providers/file_transfer_port_provider.dart';
import 'package:lockspire/features/vault/presentation/providers/installed_app_icon_provider.dart';
import 'package:lockspire/features/vault/presentation/providers/site_icons_providers.dart';
import 'package:lockspire/features/vault/presentation/providers/master_password_reminder_settings_port_provider.dart';
import 'package:lockspire/features/vault/presentation/providers/password_unlock_history_port_provider.dart';
import 'package:lockspire/features/vault/presentation/providers/vault_storage_port_provider.dart';
import 'package:lockspire/l10n/l10n.dart';
import 'package:lockspire/main.dart';
import 'package:lockspire/shared/platform_capabilities.dart';

import 'fakes/fake_about_ports.dart';
import 'fakes/fake_android_ports.dart';
import 'fakes/fake_autofill_host.dart';
import 'fakes/fake_desktop_ports.dart';
import 'fakes/fake_file_transfer.dart';
import 'fakes/fake_native_messaging.dart';
import 'fakes/fake_site_icons.dart';
import 'fakes/fake_system_accent.dart';
import 'fakes/fake_secure_clipboard.dart';
import 'fakes/sync_fakes.dart';
import 'fakes/vault_fakes.dart';

/// Pantalla de un teléfono: 1080×2400 px a 2,625 px por punto, unos
/// 411×914 puntos. Con densidad 1 serían 1080 puntos de ancho y la app
/// usaría el diseño de escritorio (riel lateral).
const phoneSize = Size(1080, 2400);
const phonePixelRatio = 2.625;

/// Ventana de escritorio: riel lateral y columna central.
const desktopSize = Size(1280, 800);

/// Android: autocompletado, Material You e ícono del lanzador.
const androidPlatform = PlatformCapabilities(
  isDesktop: false,
  isAndroid: true,
  biometricMethod: BiometricMethod.fingerprint,
);

/// Escritorio con bandeja (ADR 0012), sin canal con la extensión.
const desktopPlatform = PlatformCapabilities(
  isDesktop: true,
  isAndroid: false,
  biometricMethod: BiometricMethod.windowsHello,
);

/// Una plataforma sin canales nativos: ni Android (autocompletado, ícono
/// del lanzador) ni escritorio (bandeja, extensión).
const plainPlatform = PlatformCapabilities(
  isDesktop: false,
  isAndroid: false,
  biometricMethod: BiometricMethod.fingerprint,
);

/// La app completa en memoria, para tests de flujo: los casos de uso,
/// controladores, adaptadores de preferencias y pantallas reales, con solo
/// los bordes cambiados por dobles.
///
/// - Bóveda y ancestro del merge en memoria ([storage], [ancestor]), y
///   criptografía falsa y rápida ([crypto]): el cifrado real tiene sus
///   propios tests (`test/integration/`).
/// - Almacenamiento seguro simulado y propio de este "dispositivo"
///   ([secureStorage]): preferencias, nube activa, credenciales y estado de
///   sync pasan por sus adaptadores reales.
/// - [cloud]: el transporte de WebDAV va a una nube en memoria, compartible
///   entre varios [TestApp] para simular varios dispositivos. WebDAV se
///   configura desde la pantalla, como lo haría el usuario.
/// - [files]: el selector de archivos del sistema, en memoria; [links]: los
///   enlaces que se abrirían en el navegador.
/// - Sin canal con la extensión ni biometría disponible. La bandeja y la
///   ventana de escritorio (ADR 0012) solo con [desktop], en memoria.
///
/// Montar otro [TestApp] con el mismo [storage] simula cerrar la app y
/// volver a abrirla.
class TestApp {
  final FakeCryptoPort crypto;
  final FakeVaultStoragePort storage;
  final FakeVaultStoragePort ancestor;
  final FakeBiometricAuthPort biometric;
  final FakeSecureClipboard clipboard;
  final FakeSyncPort? cloud;
  final FakeFileTransfer files;
  final FakeExternalLinks links = FakeExternalLinks();

  /// Escritorio: ventana, bandeja y sesión del sistema en memoria. Solo se
  /// usan con [desktop] (la bandeja de ADR 0012 activa).
  final bool desktop;
  final window = FakeDesktopWindow();
  final tray = FakeTray();
  final osSession = FakeOsSessionEvents();

  /// Android: ajustes de autocompletado, ícono del lanzador e íconos de
  /// apps instaladas, en memoria. Solo se usan con [android].
  final bool android;
  final autofillSettings = FakeAutofillSettings();
  final launcherIcon = FakeLauncherIcon();
  final appIcons = FakeInstalledAppIcons();

  /// Extensión del navegador (ADR 0013): registro del native host en memoria
  /// y el canal ya escuchando.
  final nativeMessaging = FakeNativeMessaging();

  /// La actividad de autocompletado de Android, para [pumpAutofill].
  final autofillHost = FakeAutofillHost();

  /// Íconos de sitios (ADR 0029, 0030): los sitios y DuckDuckGo en memoria.
  final siteIcons = FakeSiteIconFetcher();
  final siteIconsFallback = FakeSiteIconFetcher();

  /// El contenedor del último arranque, para simular lo que llega de afuera
  /// (p. ej. un pedido de la extensión).
  late ProviderContainer container;
  final PlatformCapabilities platform;
  final List<Override> extraOverrides;
  final Map<String, String> secureStorage = {};

  TestApp({
    FakeCryptoPort? crypto,
    FakeVaultStoragePort? storage,
    FakeBiometricAuthPort? biometric,
    FakeSecureClipboard? clipboard,
    FakeFileTransfer? files,
    this.cloud,
    this.desktop = false,
    this.android = false,
    PlatformCapabilities? platform,
    this.extraOverrides = const [],
  }) : platform =
           platform ??
           (desktop
               ? desktopPlatform
               : android
               ? androidPlatform
               : plainPlatform),
       crypto = crypto ?? FakeCryptoPort(),
       storage = storage ?? FakeVaultStoragePort(),
       ancestor = FakeVaultStoragePort(),
       biometric =
           biometric ??
           (FakeBiometricAuthPort()
             ..available = BiometricAvailability.unavailable),
       clipboard = clipboard ?? FakeSecureClipboard(),
       files = files ?? FakeFileTransfer();

  List<Override> get overrides => [
    // La misma raíz de composición que main() (ADR 0018, 0024).
    ...appOverrides(),
    cryptoPortProvider.overrideWith((ref) async => crypto),
    vaultStoragePortProvider.overrideWith((ref) async => storage),
    syncAncestorStoragePortProvider.overrideWith((ref) async => ancestor),
    biometricAuthPortProvider.overrideWith((ref) => biometric),
    secureClipboardPortProvider.overrideWithValue(clipboard),
    fileTransferPortProvider.overrideWithValue(files),
    appInfoPortProvider.overrideWithValue(const FakeAppInfo()),
    externalLinkPortProvider.overrideWithValue(links),
    passwordUnlockHistoryPortProvider.overrideWithValue(
      FakePasswordUnlockHistoryPort(),
    ),
    masterPasswordReminderSettingsPortProvider.overrideWithValue(
      FakeMasterPasswordReminderSettingsPort(),
    ),
    isDesktopShellProvider.overrideWith((ref) => desktop),
    desktopWindowPortProvider.overrideWithValue(window),
    trayPortProvider.overrideWithValue(tray),
    themedIconFilePortProvider.overrideWithValue(FakeThemedIconFile()),
    osSessionEventsPortProvider.overrideWithValue(osSession),
    // El plugin de color del sistema no responde en tests: sin color de
    // acento, "Colores del sistema" usa Lineage.
    systemAccentColorPortProvider.overrideWithValue(const FakeSystemAccent()),
    systemAutofillSettingsPortProvider.overrideWithValue(autofillSettings),
    launcherIconPortProvider.overrideWithValue(launcherIcon),
    installedAppIconPortProvider.overrideWithValue(appIcons),
    nativeMessagingRegistrationPortProvider.overrideWithValue(nativeMessaging),
    autofillHostPortProvider.overrideWithValue(autofillHost),
    siteIconFetcherPortProvider.overrideWithValue(siteIcons),
    siteIconFallbackFetcherPortProvider.overrideWithValue(siteIconsFallback),
    browserBridgeProvider.overrideWith(
      (ref) async => BrowserBridgeStatus.running,
    ),
    platformCapabilitiesProvider.overrideWithValue(platform),
    if (cloud case final cloud?)
      syncPortForProvider(
        SyncProviderId.webdav,
      ).overrideWith((ref) async => cloud),
    ...extraOverrides,
  ];

  /// Monta [MyApp] en un teléfono (o una ventana de escritorio, con
  /// [desktop]), con el sistema en [systemLocale].
  Future<void> pump(
    WidgetTester tester, {
    Locale systemLocale = const Locale('es', 'CO'),
    Size? size,
    double? pixelRatio,
  }) => _pump(
    tester,
    const MyApp(),
    isAutofill: false,
    systemLocale: systemLocale,
    size: size,
    pixelRatio: pixelRatio,
  );

  /// Monta la pantalla de autocompletado de Android (ADR 0011), como cuando
  /// el sistema abre Lockspire para rellenar o guardar [request].
  Future<void> pumpAutofill(WidgetTester tester, AutofillRequest request) {
    autofillHost.nextRequest = request;
    return _pump(tester, const AutofillApp(), isAutofill: true);
  }

  Future<void> _pump(
    WidgetTester tester,
    Widget app, {
    required bool isAutofill,
    Locale systemLocale = const Locale('es', 'CO'),
    Size? size,
    double? pixelRatio,
  }) async {
    FlutterSecureStorage.setMockInitialValues(secureStorage);
    _clearAssetCache();
    tester.view.physicalSize = size ?? (desktop ? desktopSize : phoneSize);
    tester.view.devicePixelRatio =
        pixelRatio ?? (desktop ? 1 : phonePixelRatio);
    tester.platformDispatcher.localesTestValue = [systemLocale];
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearLocalesTestValue);

    // El mismo arranque que main(): tema, tiempo de bloqueo y servicios en
    // segundo plano (bloqueo automático, sync, íconos, lanzador).
    container = ProviderContainer(overrides: overrides);
    await startApp(container, isAutofill: isAutofill);

    await tester.pumpWidget(
      // Key nueva en cada arranque: si no, Flutter reusa el scope anterior y
      // "volver a abrir la app" no reinicia nada.
      _OwnedContainerScope(key: UniqueKey(), container: container, child: app),
    );
    await tester.pumpAndSettle();
  }
}

/// Como `ProviderScope`, descarta su contenedor al desmontarse: "cerrar la
/// app" (montar otra, o terminar el test) apaga sus servicios y
/// temporizadores, como al cerrar el proceso.
class _OwnedContainerScope extends StatefulWidget {
  final ProviderContainer container;
  final Widget child;

  const _OwnedContainerScope({
    super.key,
    required this.container,
    required this.child,
  });

  @override
  State<_OwnedContainerScope> createState() => _OwnedContainerScopeState();
}

class _OwnedContainerScopeState extends State<_OwnedContainerScope> {
  @override
  void dispose() {
    widget.container.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => UncontrolledProviderScope(
    container: widget.container,
    child: widget.child,
  );
}

/// Monta [screen] sola, con los textos en [locale] y el tamaño de un
/// teléfono, para tests de una pantalla.
Future<void> pumpScreen(
  WidgetTester tester,
  Widget screen, {
  List<Override> overrides = const [],
  Locale locale = const Locale('es'),
  Size size = phoneSize,
  double pixelRatio = phonePixelRatio,
}) async {
  _clearAssetCache();
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = pixelRatio;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: overrides,
      child: MaterialApp(
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: screen,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// `rootBundle` guarda el `Future` de cada asset cargado. Si lo cargó un test
/// anterior, ese `Future` vive en la zona de reloj simulado de aquel test y
/// en el siguiente nunca se completa (p. ej. la lista de palabras del
/// generador): cada test arranca con la caché vacía.
void _clearAssetCache() => rootBundle.clear();
