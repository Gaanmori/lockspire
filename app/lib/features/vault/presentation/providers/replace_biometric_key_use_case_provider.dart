// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Lockspire

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../application/replace_biometric_key_use_case.dart';
import 'biometric_auth_port_provider.dart';

part 'replace_biometric_key_use_case_provider.g.dart';

/// Composition root de [ReplaceBiometricKeyUseCase]. Inyectado en vez de construirse dentro del controller (revisión
/// 2026-09-25, hallazgo A5): los tests lo reemplazan igual que a los
/// puertos.
@Riverpod(keepAlive: true)
ReplaceBiometricKeyUseCase replaceBiometricKeyUseCase(Ref ref) =>
    ReplaceBiometricKeyUseCase(ref.watch(biometricAuthPortProvider));
