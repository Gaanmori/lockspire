// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Gabriel Ángel Montoya Rico

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../application/password_changed_elsewhere_port.dart';

part 'password_changed_elsewhere_port_provider.g.dart';

/// Ver [PasswordChangedElsewherePort] (ADR 0024). Por defecto no hay nada
/// pendiente; la app lo sobreescribe con la implementación de `sync` en
/// `lib/app_composition.dart`.
@Riverpod(keepAlive: true)
Future<PasswordChangedElsewherePort> passwordChangedElsewherePort(
  Ref ref,
) async => const NoPasswordChangedElsewhere();
