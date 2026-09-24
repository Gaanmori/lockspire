// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Lockspire

import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'clock_provider.g.dart';

/// Hora actual, inyectable: los tests de reglas por fecha (ADR 0017) la
/// sobreescriben en vez de esperar días reales.
@Riverpod(keepAlive: true)
DateTime Function() clock(Ref ref) => DateTime.now;
