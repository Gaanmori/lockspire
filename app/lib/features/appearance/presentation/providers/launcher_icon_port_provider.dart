// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Gabriel Ángel Montoya Rico

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../domain/ports/launcher_icon_port.dart';
import '../../infrastructure/method_channel_launcher_icon.dart';

part 'launcher_icon_port_provider.g.dart';

/// El ícono del lanzador de Android según el tema (ADR 0031).
@Riverpod(keepAlive: true)
LauncherIconPort launcherIconPort(Ref ref) => const MethodChannelLauncherIcon();
