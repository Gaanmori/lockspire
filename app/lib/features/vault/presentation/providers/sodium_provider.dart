// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Gabriel Ángel Montoya Rico

import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:sodium/sodium_sumo.dart';

part 'sodium_provider.g.dart';

/// Instancia única de libsodium (variante "sumo", ver ADR 0002) para toda
/// la sesión de la app — inicializarla es costoso, no debe repetirse.
@Riverpod(keepAlive: true)
Future<SodiumSumo> sodium(Ref ref) async => await SodiumSumoInit.init();
