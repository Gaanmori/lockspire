// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Lockspire

import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'auto_lock_timeout_provider.g.dart';

/// Tiempo de inactividad antes de bloquear automáticamente la bóveda (ver
/// docs/adr/0008-sesion-auto-lock.md). Fijo por ahora — hacerlo
/// configurable por el usuario es una feature aparte (pantalla de
/// ajustes). Sobreescribible en tests para no esperar minutos reales.
@Riverpod(keepAlive: true)
Duration autoLockTimeout(Ref ref) => const Duration(minutes: 5);
