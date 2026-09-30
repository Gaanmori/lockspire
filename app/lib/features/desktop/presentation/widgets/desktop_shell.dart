// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Gabriel Ángel Montoya Rico

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lockspire/design/lockspire_icon.dart';
import 'package:lockspire/features/appearance/presentation/providers/app_icon_colors_provider.dart';
import 'package:lockspire/l10n/l10n.dart';

import '../../../clipboard/presentation/providers/clipboard_guard_provider.dart';
import '../../../vault/presentation/vault_session_controller.dart';
import '../../../vault/presentation/vault_session_state.dart';
import '../../domain/ports/desktop_window_port.dart';
import '../../domain/ports/tray_port.dart';
import '../providers/desktop_ports_providers.dart';
import '../providers/is_desktop_shell_provider.dart';
import '../providers/os_session_events_port_provider.dart';
import '../providers/tray_hint_store_provider.dart';

/// Comportamiento de escritorio de ADR 0012: cerrar la ventana la oculta
/// en la bandeja, el icono de la bandeja permite abrir/bloquear/salir, y
/// bloquear la sesión del SO o suspender bloquea la bóveda.
///
/// Fuera de escritorio es transparente (devuelve [child] tal cual). Habla
/// con la ventana y la bandeja por [DesktopWindowPort] y [TrayPort].
class DesktopShell extends ConsumerStatefulWidget {
  final Widget child;

  const DesktopShell({super.key, required this.child});

  @override
  ConsumerState<DesktopShell> createState() => _DesktopShellState();
}

class _DesktopShellState extends ConsumerState<DesktopShell> {
  late final bool _enabled = ref.read(isDesktopShellProvider);
  late final DesktopWindowPort _window = ref.read(desktopWindowPortProvider);
  late final TrayPort _tray = ref.read(trayPortProvider);
  final _subscriptions = <StreamSubscription<Object?>>[];
  bool _quitting = false;

  @override
  void initState() {
    super.initState();
    if (!_enabled) return;
    unawaited(_window.interceptClose(true));
    _subscriptions
      ..add(_window.closeRequests.listen((_) => unawaited(_hideToTray())))
      ..add(_tray.actions.listen(_onTrayAction))
      ..add(
        ref
            .read(osSessionEventsPortProvider)
            .lockRequests
            .listen((_) => _lockVault()),
      );
    unawaited(_initTray());
    // El ícono de la ventana, la barra de tareas y la bandeja sigue al tema
    // elegido en Apariencia.
    ref.listenManual(
      appIconColorsProvider,
      (_, colors) => unawaited(_applyThemedIcon(colors)),
    );
  }

  /// El menú de la bandeja se arma con los textos del idioma de la app:
  /// si el usuario cambia de idioma, se vuelve a armar (ADR 0032).
  Locale? _menuLocale;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final locale = Localizations.localeOf(context);
    if (_enabled && _menuLocale != null && locale != _menuLocale) {
      unawaited(_updateTrayMenu(isUnlocked: _isUnlocked));
    }
    _menuLocale = locale;
  }

  @override
  void dispose() {
    for (final subscription in _subscriptions) {
      unawaited(subscription.cancel());
    }
    super.dispose();
  }

  bool get _isUnlocked =>
      ref.read(vaultSessionControllerProvider).value is VaultSessionUnlocked;

  Future<void> _initTray() async {
    await _tray.showDefaultIcon();
    await _applyThemedIcon(ref.read(appIconColorsProvider));
    await _updateTrayMenu(isUnlocked: _isUnlocked);
  }

  /// Si algo falla (disco, plugin), quedan los íconos de Lineage que trae
  /// la app instalada: no es motivo para romper nada.
  Future<void> _applyThemedIcon(LockspireIconColors colors) async {
    try {
      final path = await ref.read(themedIconFilePortProvider).write(colors);
      if (!mounted) return;
      await _window.setIcon(path);
      await _tray.setIcon(path);
    } catch (_) {
      // Ver arriba: quedan los íconos de la app instalada.
    }
  }

  Future<void> _updateTrayMenu({required bool isUnlocked}) => _tray.setMenu(
    TrayMenu(
      open: context.l10n.trayOpen,
      lock: context.l10n.commonLock,
      quit: context.l10n.trayQuit,
      lockEnabled: isUnlocked,
    ),
  );

  void _lockVault() {
    if (_isUnlocked) ref.read(vaultSessionControllerProvider.notifier).lock();
  }

  /// Bloquea (descarta la clave de memoria) y termina el proceso de verdad.
  Future<void> _quit() async {
    if (_quitting) return;
    _quitting = true;
    _lockVault();
    // Esperar al borrado antes de destruir la ventana: en Windows lo hace
    // el runner nativo, que necesita la ventana viva (hallazgo S4).
    await ref.read(clipboardGuardProvider).clearNow();
    await _tray.destroy();
    await _window.interceptClose(false);
    await _window.destroy();
  }

  void _onTrayAction(TrayAction action) {
    switch (action) {
      case TrayAction.open:
        unawaited(_window.show());
      case TrayAction.lock:
        _lockVault();
      case TrayAction.quit:
        unawaited(_quit());
    }
  }

  /// La primera vez explica que la app sigue en la bandeja (ADR 0012).
  Future<void> _hideToTray() async {
    if (_quitting) return;
    if (!await ref.read(trayHintStoreProvider).wasShown() && mounted) {
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(context.l10n.trayStillOpenTitle),
          content: Text(context.l10n.trayStillOpenBody),
          actions: [
            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(context.l10n.commonGotIt),
            ),
          ],
        ),
      );
      await ref.read(trayHintStoreProvider).markShown();
    }
    await _window.hide();
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
