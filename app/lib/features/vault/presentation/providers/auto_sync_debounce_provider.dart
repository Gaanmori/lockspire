// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Lockspire

import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'auto_sync_debounce_provider.g.dart';

/// Cuánto esperar después del último cambio de entradas antes de disparar
/// una sync automática (ver `VaultSessionController._scheduleAutoSync`) —
/// evita disparar una por cada guardado si el usuario edita varias
/// entradas seguidas. Sobreescribible en tests para no esperar segundos
/// reales, mismo patrón que `auto_lock_timeout_provider.dart`.
@Riverpod(keepAlive: true)
Duration autoSyncDebounce(Ref ref) => const Duration(seconds: 2);
