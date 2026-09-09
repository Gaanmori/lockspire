// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Lockspire

import 'dart:async';

import 'package:flutter/widgets.dart' show AppLifecycleState;
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../application/create_vault_use_case.dart';
import '../application/unlock_vault_use_case.dart';
import 'providers/auto_lock_timeout_provider.dart';
import 'providers/crypto_port_provider.dart';
import 'providers/vault_storage_port_provider.dart';
import 'vault_session_state.dart';

part 'vault_session_controller.g.dart';

/// Único lugar que conecta los casos de uso de `application/` con los
/// adaptadores reales de `infrastructure/` (vía los providers de
/// composition root) — el resto de la UI solo habla con este controller.
///
/// También gestiona el auto-lock (ver docs/adr/0008-sesion-auto-lock.md):
/// por inactividad y al pasar la app a segundo plano.
///
/// `keepAlive: true` es deliberado, no solo conveniencia: si este
/// controller se auto-dispusiera al quedar momentáneamente sin listeners
/// (ej. durante una transición de pantalla), perdería el estado de
/// sesión — incluida la bóveda desbloqueada en memoria — de forma
/// impredecible. Es el mismo singleton-por-sesión-de-app que ya usan los
/// providers de composition root (`crypto_port_provider.dart`, etc.).
@Riverpod(keepAlive: true)
class VaultSessionController extends _$VaultSessionController {
  Timer? _inactivityTimer;

  @override
  Future<VaultSessionState> build() async {
    ref.onDispose(() => _inactivityTimer?.cancel());

    final storage = await ref.watch(vaultStoragePortProvider.future);
    final exists = await storage.exists();
    return exists ? const VaultSessionLocked() : const VaultSessionNoVault();
  }

  Future<void> createVault(String masterPassword) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final storage = await ref.read(vaultStoragePortProvider.future);
      final crypto = await ref.read(cryptoPortProvider.future);
      final vault = await CreateVaultUseCase(storage: storage, crypto: crypto)(
        masterPassword: masterPassword,
      );
      return VaultSessionUnlocked(vault);
    });
    _scheduleAutoLockIfUnlocked();
  }

  Future<void> unlock(String masterPassword) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final storage = await ref.read(vaultStoragePortProvider.future);
      final crypto = await ref.read(cryptoPortProvider.future);
      final vault = await UnlockVaultUseCase(storage: storage, crypto: crypto)(
        masterPassword: masterPassword,
      );
      return VaultSessionUnlocked(vault);
    });
    _scheduleAutoLockIfUnlocked();
  }

  void lock() {
    _inactivityTimer?.cancel();
    state = const AsyncData(VaultSessionLocked());
  }

  /// Reinicia el temporizador de inactividad. No hace nada si la bóveda
  /// no está desbloqueada — no hay nada que proteger todavía.
  void registerActivity() {
    if (state.value is VaultSessionUnlocked) {
      _scheduleAutoLockIfUnlocked();
    }
  }

  /// Reenviado desde [ActivityAndLifecycleWatcher]. Bloquea inmediatamente
  /// al pasar a segundo plano (`paused`/`hidden`) — `inactive` se ignora a
  /// propósito, ver ADR 0008.
  void onAppLifecycleChanged(AppLifecycleState lifecycleState) {
    final isBackgrounded =
        lifecycleState == AppLifecycleState.paused ||
        lifecycleState == AppLifecycleState.hidden;
    if (isBackgrounded && state.value is VaultSessionUnlocked) {
      lock();
    }
  }

  void _scheduleAutoLockIfUnlocked() {
    _inactivityTimer?.cancel();
    if (state.value is! VaultSessionUnlocked) return;
    final timeout = ref.read(autoLockTimeoutProvider);
    _inactivityTimer = Timer(timeout, lock);
  }
}
