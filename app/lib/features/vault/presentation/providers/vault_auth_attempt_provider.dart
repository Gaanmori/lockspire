// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Lockspire

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

/// Estado del intento de crear/desbloquear la bóveda en curso — separado a
/// propósito de `vaultSessionControllerProvider`.
///
/// Antes, `createVault()`/`unlock()` ponían el estado de sesión completo en
/// `AsyncLoading()`/`AsyncError()` mientras corrían. Eso hacía que
/// `VaultGateScreen` (que decide qué pantalla mostrar según ese mismo
/// estado) reemplazara `CreateVaultScreen`/`UnlockVaultScreen` — con su
/// AppBar, título y su propio indicador de progreso — por una pantalla
/// vacía y genérica durante los ~3.5s de Argon2id, y por un error genérico
/// con botón "Reintentar" si la contraseña era incorrecta, en vez del
/// mensaje "Contraseña incorrecta" inline que ya manejaba la pantalla.
///
/// Separando este estado transitorio del estado de sesión, `Create/UnlockVaultScreen`
/// se mantienen montadas durante todo el intento — `VaultGateScreen` nunca
/// necesita enterarse.
final vaultAuthAttemptProvider = StateProvider<AsyncValue<void>>(
  (ref) => const AsyncData(null),
);
