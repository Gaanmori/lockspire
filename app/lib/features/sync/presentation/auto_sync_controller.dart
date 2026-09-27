// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Lockspire

import 'dart:async';

import 'package:lockspire/features/vault/domain/vault_event.dart';
import 'package:lockspire/features/vault/presentation/providers/vault_events_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'providers/auto_sync_debounce_provider.dart';
import 'providers/is_sync_configured_provider.dart';
import 'sync_controller.dart';

part 'auto_sync_controller.g.dart';

/// Sincroniza sola, reaccionando a los [VaultEvent] de la sesión (hallazgo
/// A3: antes lo hacía `VaultSessionController` llamando a `SyncController`,
/// lo que creaba un ciclo entre `vault` y `sync`). Se instancia al arrancar
/// la app (`main.dart`).
@Riverpod(keepAlive: true)
AutoSyncController autoSyncController(Ref ref) {
  final controller = AutoSyncController._(ref);
  final subscription = ref.read(vaultEventsProvider).events.listen(
    controller._onVaultEvent,
  );
  ref.onDispose(() {
    subscription.cancel();
    controller._cancelPending();
  });
  return controller;
}

class AutoSyncController {
  final Ref _ref;
  Timer? _pending;

  AutoSyncController._(this._ref);

  void _onVaultEvent(VaultEvent event) {
    switch (event) {
      // Evento único, sin riesgo de ráfaga: sin espera.
      case VaultEvent.unlocked:
        _cancelPending();
        unawaited(_syncIfConfigured());
      // Varios guardados seguidos (p. ej. editar varias entradas rápido) no
      // deben disparar una sync por cada uno.
      case VaultEvent.saved:
        _cancelPending();
        _pending = Timer(
          _ref.read(autoSyncDebounceProvider),
          () => unawaited(_syncIfConfigured()),
        );
      case VaultEvent.locked || VaultEvent.rekeying:
        _cancelPending();
    }
  }

  void _cancelPending() {
    _pending?.cancel();
    _pending = null;
  }

  /// Sin sync configurada no hace nada, ni siquiera deja un error guardado
  /// en `syncControllerProvider`: un intento automático silencioso no debe
  /// generar un mensaje que el usuario nunca pidió ver. Cualquier otra
  /// falla queda en el estado de `SyncController` (vía `syncNow()`, que ya
  /// usa `AsyncValue.guard`). El `try/catch` es una segunda red deliberada:
  /// un intento automático nunca debe convertirse en una excepción sin
  /// manejar, porque el guardado o el desbloqueo local ya tuvieron éxito.
  Future<void> _syncIfConfigured() async {
    try {
      if (!await _ref.read(isSyncConfiguredProvider.future)) return;
      await _ref.read(syncControllerProvider.notifier).syncNow();
    } catch (_) {
      // Silencioso a propósito, ver arriba.
    }
  }
}
