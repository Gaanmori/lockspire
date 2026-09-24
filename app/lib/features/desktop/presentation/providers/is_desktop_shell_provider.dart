// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Lockspire

import 'dart:io' show Platform;

import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'is_desktop_shell_provider.g.dart';

/// `true` en las plataformas donde la app vive en la bandeja del sistema
/// (ADR 0012). Sobreescribible en tests de widgets, que corren en un host
/// de escritorio pero no tienen ventana ni bandeja reales.
@Riverpod(keepAlive: true)
bool isDesktopShell(Ref ref) => Platform.isWindows || Platform.isLinux;
