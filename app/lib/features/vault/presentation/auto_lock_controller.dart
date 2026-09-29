// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Gabriel Ángel Montoya Rico

import 'dart:async';

import 'package:flutter/widgets.dart' show AppLifecycleState;
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'providers/auto_lock_timeout_provider.dart';
import 'providers/lock_on_background_provider.dart';
import 'vault_session_controller.dart';
import 'vault_session_state.dart';

part 'auto_lock_controller.g.dart';

/// Bloqueo automático (ADR 0008, 0012 y 0016): por inactividad y al pasar
/// a segundo plano. Separado de `VaultSessionController` (revisión
/// 2026-09-25, hallazgo A1): **escucha** la sesión en vez de que la sesión
/// lo invoque en cada desbloqueo.
///
/// Se instancia al arrancar la app (`main.dart`), así protege también la
/// pantalla de autocompletado de Android, que no tiene el observador de
/// actividad.
@Riverpod(keepAlive: true)
AutoLockController autoLockController(Ref ref) {
  final controller = AutoLockController._(ref);
  ref.onDispose(controller._cancel);
  // Cada vez que la sesión queda desbloqueada (desbloqueo, guardado,
  // cambio de contraseña) se reinicia el plazo; al bloquearse, se cancela.
  ref.listen(
    vaultSessionControllerProvider,
    (_, next) => controller._onSession(next.value),
    fireImmediately: true,
  );
  // Si el usuario cambia el tiempo de bloqueo, el temporizador en curso se
  // reprograma ya con el valor nuevo.
  ref.listen(autoLockTimeoutProvider, (_, _) => controller.registerActivity());
  return controller;
}

class AutoLockController {
  final Ref _ref;
  Timer? _timer;
  bool _unlocked = false;

  AutoLockController._(this._ref);

  /// Reinicia el plazo de inactividad. Sin bóveda desbloqueada no hace
  /// nada: no hay nada que proteger todavía.
  void registerActivity() {
    if (_unlocked) _schedule();
  }

  /// Bloquea inmediatamente al pasar a segundo plano (`paused`/`hidden`);
  /// `inactive` se ignora a propósito (ADR 0008). En escritorio no hace
  /// nada: ocultar la ventana no bloquea (ADR 0012, ver
  /// `lockOnBackgroundProvider`).
  ///
  /// No borra el portapapeles: el usuario sale de Lockspire justamente para
  /// pegar en otra app (ver `VaultSessionController.lock`).
  void onAppLifecycleChanged(AppLifecycleState lifecycleState) {
    if (!_ref.read(lockOnBackgroundProvider)) return;
    final backgrounded =
        lifecycleState == AppLifecycleState.paused ||
        lifecycleState == AppLifecycleState.hidden;
    if (backgrounded && _unlocked) _lock(keepClipboard: true);
  }

  void _onSession(VaultSessionState? session) {
    _unlocked = session is VaultSessionUnlocked;
    _unlocked ? _schedule() : _cancel();
  }

  void _schedule() {
    _cancel();
    _timer = Timer(_ref.read(autoLockTimeoutProvider), _lock);
  }

  void _cancel() {
    _timer?.cancel();
    _timer = null;
  }

  void _lock({bool keepClipboard = false}) => _ref
      .read(vaultSessionControllerProvider.notifier)
      .lock(keepClipboard: keepClipboard);
}
