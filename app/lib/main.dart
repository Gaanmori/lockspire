// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Lockspire

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'design/lockspire_theme.dart';
import 'features/autofill/presentation/autofill_app.dart';
import 'features/vault/presentation/screens/vault_gate_screen.dart';
import 'features/vault/presentation/vault_session_controller.dart';
import 'features/vault/presentation/vault_session_state.dart';
import 'features/vault/presentation/widgets/activity_and_lifecycle_watcher.dart';

void main() {
  // AutofillActivity (ADR 0011) arranca el mismo entrypoint con la ruta
  // inicial `/autofill` (ver `AutofillActivity.getInitialRoute()`) en vez
  // de un entrypoint Dart separado — evita la complejidad de compilar un
  // segundo `@pragma('vm:entry-point')`/snapshot AOT solo para esto.
  final isAutofill =
      WidgetsBinding.instance.platformDispatcher.defaultRouteName ==
      '/autofill';
  runApp(
    ProviderScope(child: isAutofill ? const AutofillApp() : const MyApp()),
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

    return MaterialApp(
      navigatorKey: navigatorKey,
      title: 'Lockspire',
      theme: LockspireTheme.themeData,
      home: const ActivityAndLifecycleWatcher(child: VaultGateScreen()),
    );
  }
}
