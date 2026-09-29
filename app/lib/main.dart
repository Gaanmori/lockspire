// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Lockspire

import 'dart:io' show Platform, exit;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';

import 'app_composition.dart';
import 'app_shell.dart';
import 'design/lockspire_icon.dart';
import 'features/appearance/presentation/providers/app_icon_colors_provider.dart';
import 'features/appearance/presentation/appearance_controller.dart';
import 'features/appearance/presentation/providers/app_themes_provider.dart';
import 'features/appearance/presentation/providers/system_accent_color_provider.dart';
import 'features/autofill/presentation/autofill_app.dart';
import 'features/browser_bridge/infrastructure/single_instance.dart';
import 'features/browser_bridge/presentation/providers/browser_bridge_provider.dart';
import 'features/browser_bridge/presentation/widgets/link_request_listener.dart';
import 'features/desktop/presentation/widgets/desktop_shell.dart';
import 'features/sync/presentation/auto_sync_controller.dart';
import 'features/sync/presentation/screens/restore_vault_screen.dart';
import 'features/vault/presentation/auto_lock_controller.dart';
import 'features/vault/presentation/providers/auto_lock_timeout_setting_provider.dart';
import 'features/vault/presentation/screens/vault_gate_screen.dart';
import 'features/vault/presentation/vault_session_controller.dart';
import 'features/vault/presentation/vault_session_state.dart';
import 'features/vault/presentation/widgets/activity_and_lifecycle_watcher.dart';

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
  final container = ProviderContainer(overrides: appOverrides());
  // El tema elegido se carga antes del primer frame: si no, la app
  // mostraría un instante el tema por defecto y luego cambiaría.
  await container.read(appearanceControllerProvider.future);
  await container.read(systemAccentColorProvider.future);
  // Igual con el tiempo de bloqueo (ADR 0016): el primer desbloqueo ya
  // usa el valor guardado.
  await container.read(autoLockTimeoutSettingProvider.future);
  // El bloqueo automático escucha la sesión desde el arranque, también en
  // la pantalla de autocompletado de Android (hallazgo A1).
  container.read(autoLockControllerProvider);
  // La sync automática escucha los eventos de la bóveda (hallazgo A3).
  // No en el autocompletado de Android: rellenar no necesita la nube, y
  // conectar Google Drive ahí muestra la ventana "Iniciando sesión" encima
  // de la app que pide (ADR 0026). Lo guardado desde ahí se sube en la
  // próxima sync de la app.
  if (!isAutofill) container.read(autoSyncControllerProvider);
  if (Platform.isWindows || Platform.isLinux) {
    // DesktopShell (ADR 0012) usa window_manager, que exige inicializarse
    // antes de runApp().
    await windowManager.ensureInitialized();
    // El canal de la extensión (ADR 0013) arranca antes de la UI: si otra
    // instancia ya lo tiene, se le pide que muestre su ventana y esta
    // termina sin llegar a abrir la suya (instancia única, ADR 0012). Si
    // la otra no responde (colgada, o el canal no es de confianza), esta
    // sigue arrancando sin canal — la pantalla "Navegador" lo indica.
    final bridge = await container.read(browserBridgeProvider.future);
    if (bridge == BrowserBridgeStatus.anotherInstance &&
        await signalExistingInstance()) {
      exit(0);
    }
  }
  runApp(
    UncontrolledProviderScope(
      container: container,
      child: isAutofill ? const AutofillApp() : const MyApp(),
    ),
  );
}

/// Dueño único del `Navigator` de la app — lo necesita [MyApp] para poder
/// descartar pantallas empujadas (Sync, Seguridad, Importar, editar una
/// entrada) cuando la sesión se bloquea, ver el comentario en `build()`.
final navigatorKey = GlobalKey<NavigatorState>();

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
        navigatorKey.currentState?.popUntil((route) => route.isFirst);
      }
    });

    final themes = ref.watch(appThemesProvider);

    return LockspireBrand(
      colors: ref.watch(appIconColorsProvider),
      child: MaterialApp(
        navigatorKey: navigatorKey,
        title: 'Lockspire',
        theme: themes.light,
        darkTheme: themes.dark,
        themeMode: themes.mode,
        // DesktopShell dentro de MaterialApp: necesita un Navigator para
        // mostrar el aviso de "sigue en la bandeja" al cerrar la ventana.
        home: DesktopShell(
          child: LinkRequestListener(
            child: ActivityAndLifecycleWatcher(
              child: VaultGateScreen(
                unlockedBuilder: (vault) => AppShell(vault: vault),
                restoreVaultBuilder: (_) => const RestoreVaultScreen(),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
