// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Lockspire

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../vault_session_controller.dart';

/// Envuelve toda la app: detecta actividad del usuario (para reiniciar el
/// timer de auto-lock) y cambios de ciclo de vida (para bloquear al pasar
/// a segundo plano). Ver docs/adr/0008-sesion-auto-lock.md.
///
/// Un solo tap no basta como señal de actividad — alguien escribiendo en
/// un campo largo o haciendo scroll sin volver a tocar la pantalla
/// también cuenta, así que se cubren tres vías: punteros, scroll/trackpad
/// y teclado.
class ActivityAndLifecycleWatcher extends ConsumerStatefulWidget {
  final Widget child;

  const ActivityAndLifecycleWatcher({super.key, required this.child});

  @override
  ConsumerState<ActivityAndLifecycleWatcher> createState() =>
      _ActivityAndLifecycleWatcherState();
}

class _ActivityAndLifecycleWatcherState
    extends ConsumerState<ActivityAndLifecycleWatcher> {
  late final AppLifecycleListener _lifecycleListener;

  @override
  void initState() {
    super.initState();
    _lifecycleListener = AppLifecycleListener(
      onStateChange: (state) => ref
          .read(vaultSessionControllerProvider.notifier)
          .onAppLifecycleChanged(state),
    );
    HardwareKeyboard.instance.addHandler(_onKeyEvent);
  }

  @override
  void dispose() {
    _lifecycleListener.dispose();
    HardwareKeyboard.instance.removeHandler(_onKeyEvent);
    super.dispose();
  }

  bool _onKeyEvent(KeyEvent event) {
    _registerActivity();
    return false; // no consume el evento, solo lo observa
  }

  void _registerActivity() {
    ref.read(vaultSessionControllerProvider.notifier).registerActivity();
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) => _registerActivity(),
      onPointerSignal: (_) => _registerActivity(),
      child: widget.child,
    );
  }
}
