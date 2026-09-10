// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Lockspire

import 'dart:async';

import 'package:flutter/widgets.dart' show AppLifecycleState;
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../application/create_vault_use_case.dart';
import '../application/save_vault_use_case.dart';
import '../application/unlock_vault_use_case.dart';
import '../domain/entities/vault.dart';
import '../domain/entities/vault_entry.dart';
import '../domain/vault_file_codec.dart';
import 'providers/auto_lock_timeout_provider.dart';
import 'providers/crypto_port_provider.dart';
import 'providers/vault_auth_attempt_provider.dart';
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

  /// Crea la bóveda. El progreso/error de este intento se refleja en
  /// [vaultAuthAttemptProvider], **no** en el estado de este controller —
  /// ver el comentario de ese provider para el porqué: si este `state`
  /// pasara por `AsyncLoading`/`AsyncError` mientras corre, `VaultGateScreen`
  /// reemplazaría `CreateVaultScreen` por una pantalla genérica sin
  /// contexto durante los ~3.5s de Argon2id.
  Future<void> createVault(String masterPassword) async {
    final attempt = ref.read(vaultAuthAttemptProvider.notifier);
    attempt.state = const AsyncLoading();
    try {
      final storage = await ref.read(vaultStoragePortProvider.future);
      final crypto = await ref.read(cryptoPortProvider.future);
      final created = await CreateVaultUseCase(
        storage: storage,
        crypto: crypto,
      )(masterPassword: masterPassword);
      state = AsyncData(
        VaultSessionUnlocked(
          vault: created.vault,
          key: created.key,
          header: created.header,
          fileHash: created.fileHash,
        ),
      );
      attempt.state = const AsyncData(null);
    } catch (error, stackTrace) {
      attempt.state = AsyncError(error, stackTrace);
    }
    _scheduleAutoLockIfUnlocked();
  }

  /// Desbloquea la bóveda existente. Ver el comentario de [createVault]:
  /// mismo motivo para no tocar `state` mientras corre.
  Future<void> unlock(String masterPassword) async {
    final attempt = ref.read(vaultAuthAttemptProvider.notifier);
    attempt.state = const AsyncLoading();
    try {
      final storage = await ref.read(vaultStoragePortProvider.future);
      final crypto = await ref.read(cryptoPortProvider.future);
      final unlocked = await UnlockVaultUseCase(
        storage: storage,
        crypto: crypto,
      )(masterPassword: masterPassword);
      state = AsyncData(
        VaultSessionUnlocked(
          vault: unlocked.vault,
          key: unlocked.key,
          header: unlocked.header,
          fileHash: unlocked.fileHash,
        ),
      );
      attempt.state = const AsyncData(null);
    } catch (error, stackTrace) {
      attempt.state = AsyncError(error, stackTrace);
    }
    _scheduleAutoLockIfUnlocked();
  }

  void lock() {
    _inactivityTimer?.cancel();
    state = const AsyncData(VaultSessionLocked());
    // Limpia cualquier error/loading de un intento anterior — la próxima
    // vez que se muestre UnlockVaultScreen debe arrancar en blanco, no con
    // el "Contraseña incorrecta" de la sesión previa.
    ref.read(vaultAuthAttemptProvider.notifier).state = const AsyncData(null);
  }

  /// Agrega una entrada nueva de tipo contraseña. Lanza
  /// [VaultWriteConflictException] si la bóveda cambió en disco desde la
  /// última lectura de esta sesión (ver `SaveVaultUseCase`) — en ese caso
  /// el estado ya queda actualizado con la versión fresca antes de
  /// relanzar, para que un reintento inmediato parta de datos vigentes.
  Future<void> addEntry({
    required String title,
    Map<String, String> fields = const {},
  }) async {
    final current = state.value;
    if (current is! VaultSessionUnlocked) return;
    final entry = VaultEntry.create(title: title, fields: fields);
    await _persist(
      current.vault.copyWith(entries: [...current.vault.entries, entry]),
    );
  }

  /// Edita una entrada existente. Ver [addEntry] para el manejo de
  /// conflicto de guardado.
  Future<void> updateEntry({
    required String id,
    required String title,
    required Map<String, String> fields,
  }) async {
    final current = state.value;
    if (current is! VaultSessionUnlocked) return;
    final now = DateTime.now().toUtc();
    final entries = current.vault.entries
        .map(
          (e) => e.id == id
              ? e.copyWith(title: title, fields: fields, modifiedAt: now)
              : e,
        )
        .toList();
    await _persist(current.vault.copyWith(entries: entries));
  }

  /// Borrado suave (tombstone) — no quita la entrada de la lista, la marca
  /// como borrada (ver comentario en `VaultEntry.deleted`). Ver [addEntry]
  /// para el manejo de conflicto de guardado.
  Future<void> deleteEntry(String id) async {
    final current = state.value;
    if (current is! VaultSessionUnlocked) return;
    final now = DateTime.now().toUtc();
    final entries = current.vault.entries
        .map(
          (e) => e.id == id
              ? e.copyWith(deleted: true, deletedAt: now, modifiedAt: now)
              : e,
        )
        .toList();
    await _persist(current.vault.copyWith(entries: entries));
  }

  Future<void> _persist(Vault newVault) async {
    final current = state.value;
    if (current is! VaultSessionUnlocked) return;

    final storage = await ref.read(vaultStoragePortProvider.future);
    final crypto = await ref.read(cryptoPortProvider.future);

    try {
      final file = await SaveVaultUseCase(storage: storage, crypto: crypto)
          .call(
            vault: newVault,
            key: current.key,
            header: current.header,
            expectedFileHash: current.fileHash,
          );
      state = AsyncData(
        current.copyWith(
          vault: newVault,
          fileHash: VaultFileCodec.sha256Hex(file),
        ),
      );
    } on VaultWriteConflictException {
      // La contraseña maestra no cambió — solo el contenido en disco
      // (típicamente otro dispositivo sincronizó). Se recarga con la
      // misma key ya retenida, sin pedir la contraseña de nuevo.
      final reloaded = await UnlockVaultUseCase(
        storage: storage,
        crypto: crypto,
      ).reloadWithKey(key: current.key);
      state = AsyncData(
        VaultSessionUnlocked(
          vault: reloaded.vault,
          key: reloaded.key,
          header: reloaded.header,
          fileHash: reloaded.fileHash,
        ),
      );
      rethrow;
    }
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
