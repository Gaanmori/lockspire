// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Gabriel Ángel Montoya Rico

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../clipboard/presentation/providers/clipboard_guard_provider.dart';
import '../auto_lock_controller.dart';

/// Envuelve toda la app: detecta actividad del usuario (para reiniciar el
/// timer de auto-lock) y cambios de ciclo de vida (para bloquear al pasar
/// a segundo plano). Ver docs/adr/0008-sesion-auto-lock.md.
///
/// Un solo tap no basta como señal de actividad — alguien escribiendo en
/// un campo largo o haciendo scroll sin volver a tocar la pantalla
/// también cuenta, así que se cubren cuatro vías: punteros, scroll/trackpad,
/// teclado físico y texto escrito.
///
/// **Texto escrito:** el teclado en pantalla de Android escribe por el canal
/// del método de entrada: no produce eventos de `HardwareKeyboard`, y sus
/// toques son en la ventana del teclado, no en la app. Sin esta vía, quien
/// escribía una nota larga sin tocar la app veía bloquearse la bóveda (y
/// cerrarse el formulario sin guardar) a los 5 minutos (encontrado por un
/// test de flujo, 2026-09-29). Cada [_typingCheckInterval] se mira si el
/// campo con el foco cambió; solo se guarda un hash del texto.
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
  late final Timer _typingCheck;
  int? _lastFocusedTextHash;

  static const _typingCheckInterval = Duration(seconds: 15);

  @override
  void initState() {
    super.initState();
    _lifecycleListener = AppLifecycleListener(
      onStateChange: (state) {
        ref.read(autoLockControllerProvider).onAppLifecycleChanged(state);
        // Reintenta el borrado del portapapeles si venció fuera de la app
        // (HyperOS lo descarta en segundo plano, ver ClipboardGuard).
        if (state == AppLifecycleState.resumed) {
          unawaited(ref.read(clipboardGuardProvider).onResumed());
        }
      },
    );
    HardwareKeyboard.instance.addHandler(_onKeyEvent);
    _typingCheck = Timer.periodic(_typingCheckInterval, (_) => _checkTyping());
  }

  @override
  void dispose() {
    _lifecycleListener.dispose();
    HardwareKeyboard.instance.removeHandler(_onKeyEvent);
    _typingCheck.cancel();
    super.dispose();
  }

  bool _onKeyEvent(KeyEvent event) {
    _registerActivity();
    return false; // no consume el evento, solo lo observa
  }

  void _checkTyping() {
    final editable = FocusManager.instance.primaryFocus?.context
        ?.findAncestorStateOfType<EditableTextState>();
    final hash = editable?.textEditingValue.text.hashCode;
    if (hash != null &&
        _lastFocusedTextHash != null &&
        hash != _lastFocusedTextHash) {
      _registerActivity();
    }
    _lastFocusedTextHash = hash;
  }

  void _registerActivity() {
    ref.read(autoLockControllerProvider).registerActivity();
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
