// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Gabriel Ángel Montoya Rico

import 'dart:io' show Platform, exit;
import 'features/appearance/presentation/providers/app_locale_provider.dart';
import 'l10n/l10n.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';

import 'app_composition.dart';
import 'app_shell.dart';
import 'design/lockspire_icon.dart';
import 'features/appearance/presentation/providers/app_icon_colors_provider.dart';
import 'features/appearance/presentation/providers/app_themes_provider.dart';
import 'features/autofill/presentation/autofill_app.dart';
import 'features/browser_bridge/infrastructure/single_instance.dart';
import 'features/browser_bridge/presentation/providers/browser_bridge_provider.dart';
import 'features/browser_bridge/presentation/widgets/link_request_listener.dart';
import 'features/browser_bridge/presentation/widgets/browser_login_save_listener.dart';
import 'features/desktop/presentation/widgets/desktop_shell.dart';
import 'features/profiles/presentation/profile_switcher.dart';
import 'features/profiles/presentation/providers/profile_providers.dart';
import 'features/profiles/presentation/start_profile.dart';
import 'features/profiles/presentation/widgets/profile_host.dart';
import 'features/profiles/presentation/widgets/profile_widgets.dart';
import 'features/sync/presentation/screens/restore_vault_screen.dart';
import 'features/vault/presentation/screens/vault_gate_screen.dart';
import 'features/vault/presentation/vault_session_controller.dart';
import 'features/vault/presentation/vault_session_state.dart';
import 'features/vault/presentation/widgets/activity_and_lifecycle_watcher.dart';
import 'shared/secure_storage_provider.dart';

Future<void> main() async {
  // WidgetsBinding.instance no existe hasta que se inicializa el binding
  // — runApp() lo hace por dentro, pero acá hace falta leer la ruta
  // inicial *antes* de decidir a qué widget llamar runApp(), así que se
  // inicializa a mano primero (idempotente, runApp() lo detecta y no
  // vuelve a inicializar).
  WidgetsFlutterBinding.ensureInitialized();
  // AutofillActivity (ADR 0011) arranca el mismo entrypoint con la ruta
  // inicial `/autofill` (ver `AutofillActivity.getInitialRoute()`) en vez
  // de un entrypoint Dart separado — evita la complejidad de compilar un
  // segundo `@pragma('vm:entry-point')`/snapshot AOT solo para esto.
  final isAutofill =
      WidgetsBinding.instance.platformDispatcher.defaultRouteName ==
      '/autofill';
  final isDesktop = Platform.isWindows || Platform.isLinux;
  if (isDesktop) {
    // DesktopShell (ADR 0012) usa window_manager, que exige inicializarse
    // antes de runApp().
    await windowManager.ensureInitialized();
  }

  // Cada perfil tiene su propio contenedor (ADR 0039): se abre el último
  // usado, y cambiar de perfil crea otro con `boot`.
  Future<ProviderContainer> boot(String profileId, ProfileSwitcher s) async {
    final container = ProviderContainer(
      overrides: [
        ...appOverrides(),
        activeProfileIdProvider.overrideWithValue(profileId),
        profileSwitcherProvider.overrideWithValue(s),
      ],
    );
    await startApp(container, isAutofill: isAutofill);
    // El canal de la extensión (ADR 0013) arranca antes de la UI.
    if (isDesktop) await container.read(browserBridgeProvider.future);
    return container;
  }

  final handle = ProfileSwitchHandle();
  final container = await boot(await startProfileId(), handle);
  // Si otra instancia ya tiene el canal, se le pide que muestre su ventana
  // y esta termina sin llegar a abrir la suya (instancia única, ADR 0012).
  // Si la otra no responde (colgada, o el canal no es de confianza), esta
  // sigue arrancando sin canal — la pantalla "Navegador" lo indica.
  if (isDesktop &&
      container.read(browserBridgeProvider).value ==
          BrowserBridgeStatus.anotherInstance &&
      await signalExistingInstance()) {
    exit(0);
  }
  runApp(
    ProfileHost(
      handle: handle,
      initialContainer: container,
      boot: boot,
      child: isAutofill ? const AutofillApp() : const MyApp(),
    ),
  );
}

class MyApp extends ConsumerStatefulWidget {
  const MyApp({super.key});

  @override
  ConsumerState<MyApp> createState() => _MyAppState();
}

class _MyAppState extends ConsumerState<MyApp> {
  /// Dueño del `Navigator` de la app: hace falta para descartar pantallas
  /// empujadas (Sync, Seguridad, Importar, editar una entrada) cuando la
  /// sesión se bloquea, ver el comentario en `build()`. Es de esta instancia
  /// y no global: una `GlobalKey` global hacía que otro `MyApp` heredara la
  /// pila de pantallas del anterior.
  final _navigatorKey = GlobalKey<NavigatorState>();

  @override
  Widget build(BuildContext context) {
    // VaultGateScreen (home) es un swap condicional sin Navigator propio
    // — reacciona solo a vaultSessionControllerProvider. Pero pantallas
    // como SyncSettingsScreen se abren con Navigator.push por encima de
    // ese home, y quedan "huérfanas" si la sesión se bloquea mientras
    // están abiertas (auto-lock por inactividad/backgrounding — ADR
    // 0008 — o el botón manual "Bloquear"): VaultGateScreen sí cambia a
    // UnlockVaultScreen por dentro, pero queda tapado por la pantalla
    // empujada, que no tiene forma de enterarse. Este listener cierra
    // todas las pantallas empujadas apenas la sesión deja de estar
    // desbloqueada, para que UnlockVaultScreen vuelva a quedar visible.
    // Trade-off aceptado: si había una entrada sin guardar en
    // EntryFormScreen, se pierde — mismo resultado práctico que ya
    // existía en silencio (guardar contra una sesión bloqueada ya
    // fallaba), esto solo lo hace visible en vez de dejar la pantalla
    // ahí sin decir nada.
    ref.listen<AsyncValue<VaultSessionState>>(vaultSessionControllerProvider, (
      previous,
      next,
    ) {
      final wasUnlocked = previous?.value is VaultSessionUnlocked;
      final isUnlocked = next.value is VaultSessionUnlocked;
      if (wasUnlocked && !isUnlocked) {
        _navigatorKey.currentState?.popUntil((route) => route.isFirst);
      }
    });

    final themes = ref.watch(appThemesProvider);

    return LockspireBrand(
      colors: ref.watch(appIconColorsProvider),
      child: MaterialApp(
        navigatorKey: _navigatorKey,
        title: 'Lockspire',
        locale: ref.watch(appLocaleProvider),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        localeListResolutionCallback: (locales, _) =>
            resolveSystemLocale(locales),
        theme: themes.light,
        darkTheme: themes.dark,
        themeMode: themes.mode,
        // DesktopShell dentro de MaterialApp: necesita un Navigator para
        // mostrar el aviso de "sigue en la bandeja" al cerrar la ventana.
        home: DesktopShell(
          child: LinkRequestListener(
            child: BrowserLoginSaveListener(
              child: ActivityAndLifecycleWatcher(
                child: VaultGateScreen(
                  unlockedBuilder: (vault) => AppShell(vault: vault),
                  restoreVaultBuilder: (_) => const RestoreVaultScreen(),
                  // Con varios perfiles, se elige al abrir (ADR 0039).
                  lockedHeader: const ProfilePicker(),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
