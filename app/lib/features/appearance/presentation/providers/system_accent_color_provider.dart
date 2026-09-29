// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Gabriel Ángel Montoya Rico

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../domain/ports/system_accent_color_port.dart';
import '../../infrastructure/dynamic_color_accent_adapter.dart';

part 'system_accent_color_provider.g.dart';

@Riverpod(keepAlive: true)
SystemAccentColorPort systemAccentColorPort(Ref ref) =>
    const DynamicColorAccentAdapter();

/// Color del sistema (ARGB) o `null` si la plataforma no lo ofrece. Se lee
/// una vez al arrancar (`main()`); si el usuario cambia el color de acento
/// con la app abierta, se aplica en el próximo arranque.
@Riverpod(keepAlive: true)
Future<int?> systemAccentColor(Ref ref) =>
    ref.watch(systemAccentColorPortProvider).accentColorArgb();
