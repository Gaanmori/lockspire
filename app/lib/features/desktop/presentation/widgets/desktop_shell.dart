// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Lockspire

import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';

import '../../../clipboard/presentation/providers/clipboard_guard_provider.dart';
import '../../../vault/presentation/vault_session_controller.dart';
import '../../../vault/presentation/vault_session_state.dart';
import '../../infrastructure/tray_hint_store.dart';
import '../providers/is_desktop_shell_provider.dart';
import '../providers/os_session_events_port_provider.dart';
import '../window_actions.dart';

const _menuOpen = 'open';
const _menuLock = 'lock';
const _menuQuit = 'quit';

/// Comportamiento de escritorio de ADR 0012: cerrar la ventana la oculta
/// en la bandeja, el icono de la bandeja permite abrir/bloquear/salir, y
/// bloquear la sesión del SO o suspender bloquea la bóveda.
///
/// Fuera de escritorio es transparente (devuelve [child] tal cual).
/// Requiere que `windowManager.ensureInitialized()` se haya llamado en
/// `main()` antes de `runApp()`.
class DesktopShell extends ConsumerStatefulWidget {
  final Widget child;

  const DesktopShell({super.key, required this.child});

  @override
  ConsumerState<DesktopShell> createState() => _DesktopShellState();
}

class _DesktopShellState extends ConsumerState<DesktopShell>
    with WindowListener, TrayListener {
  late final bool _enabled = ref.read(isDesktopShellProvider);
  StreamSubscription<void>? _osLockSubscription;
  final _trayHintStore = const TrayHintStore();
  bool _quitting = false;

  @override
  void initState() {
    super.initState();
    if (!_enabled) return;
    windowManager.addListener(this);
    trayManager.addListener(this);
    unawaited(windowManager.setPreventClose(true));
    unawaited(_initTray());
    _osLockSubscription = ref
        .read(osSessionEventsPortProvider)
        .lockRequests
        .listen((_) => _lockVault());
  }

  @override
  void dispose() {
    if (_enabled) {
      windowManager.removeListener(this);
      trayManager.removeListener(this);
      unawaited(_osLockSubscription?.cancel());
    }
    super.dispose();
  }

  Future<void> _initTray() async {
    await trayManager.setIcon(
      Platform.isWindows
          ? 'assets/tray/tray_icon.ico'
          : 'assets/tray/tray_icon.png',
    );
    // setToolTip no está soportado por AppIndicator en Linux.
    if (Platform.isWindows) await trayManager.setToolTip('Lockspire');
    await _updateTrayMenu(
      isUnlocked:
          ref.read(vaultSessionControllerProvider).value
              is VaultSessionUnlocked,
    );
  }

  Future<void> _updateTrayMenu({required bool isUnlocked}) {
    return trayManager.setContextMenu(
      Menu(
        items: [
          MenuItem(key: _menuOpen, label: 'Abrir Lockspire'),
          MenuItem(key: _menuLock, label: 'Bloquear', disabled: !isUnlocked),
          MenuItem.separator(),
          MenuItem(key: _menuQuit, label: 'Salir'),
        ],
      ),
    );
  }

  void _lockVault() {
    final session = ref.read(vaultSessionControllerProvider).value;
    if (session is VaultSessionUnlocked) {
      ref.read(vaultSessionControllerProvider.notifier).lock();
    }
  }

  Future<void> _showWindow() => showMainWindow();

  /// Bloquea (descarta la clave de memoria) y termina el proceso de verdad.
  Future<void> _quit() async {
    if (_quitting) return;
    _quitting = true;
    _lockVault();
    // Esperar al borrado antes de destruir la ventana: en Windows lo hace
    // el runner nativo, que necesita la ventana viva (hallazgo S4).
    await ref.read(clipboardGuardProvider).clearNow();
    await trayManager.destroy();
    await windowManager.setPreventClose(false);
    await windowManager.destroy();
  }

  // --- WindowListener -------------------------------------------------

  @override
  void onWindowClose() {
    unawaited(_hideToTray());
  }

  Future<void> _hideToTray() async {
    if (_quitting) return;
    if (!await _trayHintStore.wasShown() && mounted) {
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Lockspire sigue abierto'),
          content: const Text(
            'Al cerrar la ventana, Lockspire queda en la bandeja del sistema '
            'para que la extensión del navegador pueda autocompletar. La '
            'bóveda se bloquea sola tras el tiempo sin uso que elijas en '
            'Seguridad, al bloquear la sesión o al suspender el equipo.\n\n'
            'Para cerrarlo del todo, usá "Salir" en el icono de la bandeja.',
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Entendido'),
            ),
          ],
        ),
      );
      await _trayHintStore.markShown();
    }
    await windowManager.hide();
  }

  // --- TrayListener ---------------------------------------------------

  @override
  void onTrayIconMouseDown() {
    unawaited(_showWindow());
  }

  @override
  void onTrayIconRightMouseDown() {
    unawaited(trayManager.popUpContextMenu());
  }

  @override
  void onTrayMenuItemClick(MenuItem menuItem) {
    switch (menuItem.key) {
      case _menuOpen:
        unawaited(_showWindow());
      case _menuLock:
        _lockVault();
      case _menuQuit:
        unawaited(_quit());
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_enabled) {
      ref.listen<AsyncValue<VaultSessionState>>(
        vaultSessionControllerProvider,
        (previous, next) => unawaited(
          _updateTrayMenu(isUnlocked: next.value is VaultSessionUnlocked),
        ),
      );
    }
    return widget.child;
  }
}
