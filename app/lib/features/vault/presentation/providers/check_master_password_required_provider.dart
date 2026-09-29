// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Gabriel Ángel Montoya Rico

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../application/check_master_password_required_use_case.dart';
import 'clock_provider.dart';
import 'master_password_reminder_settings_port_provider.dart';
import 'password_unlock_history_port_provider.dart';

part 'check_master_password_required_provider.g.dart';

/// Composition root del caso de uso de ADR 0017. Provee el **caso de uso**,
/// no su resultado: cada llamada vuelve a evaluar la regla con los datos y
/// la hora actuales (ver [CheckMasterPasswordRequiredUseCase]).
@Riverpod(keepAlive: true)
CheckMasterPasswordRequiredUseCase checkMasterPasswordRequired(Ref ref) =>
    CheckMasterPasswordRequiredUseCase(
      settings: ref.watch(masterPasswordReminderSettingsPortProvider),
      history: ref.watch(passwordUnlockHistoryPortProvider),
      now: ref.watch(clockProvider),
    );
