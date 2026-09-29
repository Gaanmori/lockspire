// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Gabriel Ángel Montoya Rico

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../domain/auto_lock_timeout.dart';
import 'auto_lock_timeout_setting_provider.dart';

part 'auto_lock_timeout_provider.g.dart';

/// Tiempo de inactividad antes de bloquear automáticamente la bóveda (ver
/// docs/adr/0008-sesion-auto-lock.md y 0016). Es lo único que lee
/// `VaultSessionController`: no sabe de dónde sale el valor. Sobreescribible
/// en tests para no esperar minutos reales.
@Riverpod(keepAlive: true)
Duration autoLockTimeout(Ref ref) =>
    (ref.watch(autoLockTimeoutSettingProvider).value ??
            AutoLockTimeout.defaultValue)
        .duration;
