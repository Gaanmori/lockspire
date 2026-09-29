// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Gabriel Ángel Montoya Rico

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lockspire/app_composition.dart';
import 'package:lockspire/features/clipboard/presentation/providers/clipboard_guard_provider.dart';
import 'package:lockspire/features/desktop/presentation/providers/is_desktop_shell_provider.dart';
import 'package:lockspire/features/sync/domain/ports/active_sync_provider_port.dart';
import 'package:lockspire/features/sync/presentation/providers/active_sync_port_provider.dart';
import 'package:lockspire/features/sync/presentation/providers/sync_ancestor_storage_port_provider.dart';
import 'package:lockspire/features/vault/domain/ports/biometric_auth_port.dart';
import 'package:lockspire/features/vault/presentation/providers/biometric_auth_port_provider.dart';
import 'package:lockspire/features/vault/presentation/providers/crypto_port_provider.dart';
import 'package:lockspire/features/vault/presentation/providers/master_password_reminder_settings_port_provider.dart';
import 'package:lockspire/features/vault/presentation/providers/password_unlock_history_port_provider.dart';
import 'package:lockspire/features/vault/presentation/providers/vault_storage_port_provider.dart';
import 'package:lockspire/l10n/l10n.dart';
import 'package:lockspire/main.dart';
import 'package:lockspire/shared/platform_capabilities.dart';

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
/// - Sin bandeja, sin canal con la extensión, sin biometría disponible.
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
  final PlatformCapabilities platform;
  final List<Override> extraOverrides;
  final Map<String, String> secureStorage = {};

  TestApp({
    FakeCryptoPort? crypto,
    FakeVaultStoragePort? storage,
    FakeBiometricAuthPort? biometric,
    FakeSecureClipboard? clipboard,
    this.cloud,
    this.platform = plainPlatform,
    this.extraOverrides = const [],
  }) : crypto = crypto ?? FakeCryptoPort(),
       storage = storage ?? FakeVaultStoragePort(),
       ancestor = FakeVaultStoragePort(),
       biometric =
           biometric ??
           (FakeBiometricAuthPort()
             ..available = BiometricAvailability.unavailable),
       clipboard = clipboard ?? FakeSecureClipboard();

  List<Override> get overrides => [
    // La misma raíz de composición que main() (ADR 0018, 0024).
    ...appOverrides(),
    cryptoPortProvider.overrideWith((ref) async => crypto),
    vaultStoragePortProvider.overrideWith((ref) async => storage),
    syncAncestorStoragePortProvider.overrideWith((ref) async => ancestor),
    biometricAuthPortProvider.overrideWith((ref) => biometric),
    secureClipboardPortProvider.overrideWithValue(clipboard),
    passwordUnlockHistoryPortProvider.overrideWithValue(
      FakePasswordUnlockHistoryPort(),
    ),
    masterPasswordReminderSettingsPortProvider.overrideWithValue(
      FakeMasterPasswordReminderSettingsPort(),
    ),
    isDesktopShellProvider.overrideWith((ref) => false),
    platformCapabilitiesProvider.overrideWithValue(platform),
    if (cloud case final cloud?)
      syncPortForProvider(
        SyncProviderId.webdav,
      ).overrideWith((ref) async => cloud),
    ...extraOverrides,
  ];

  /// Monta [MyApp] en un teléfono, con el sistema en [systemLocale].
  Future<void> pump(
    WidgetTester tester, {
    Locale systemLocale = const Locale('es', 'CO'),
    Size size = phoneSize,
    double pixelRatio = phonePixelRatio,
  }) async {
    FlutterSecureStorage.setMockInitialValues(secureStorage);
    _clearAssetCache();
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = pixelRatio;
    tester.platformDispatcher.localesTestValue = [systemLocale];
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearLocalesTestValue);

    await tester.pumpWidget(
      // Key nueva en cada arranque: si no, Flutter reusa el ProviderScope
      // anterior y "volver a abrir la app" no reinicia nada.
      ProviderScope(
        key: UniqueKey(),
        overrides: overrides,
        child: const MyApp(),
      ),
    );
    await tester.pumpAndSettle();
  }
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
